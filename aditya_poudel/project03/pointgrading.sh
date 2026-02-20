#!/usr/bin/env bash
set -u

###############################################################################
# COSC_352_SPRING_2026 - Project03 Point Grader (Bash-only)
#
# Per project scoring (starts at 100):
#   - folder missing  => build fails + test fails => -60 => 40
#   - build fails     => test fails              => -40 => 60
#   - build ok, test fails                       => -20 => 80
#   - pass                                      => 100
#
# PASS definition for summary counts:
#   - PASS if score >= 80
#   - FAIL otherwise
#
# Projects:
#   - project01: expects exact stdout "Hello World Aditya"
#   - project02: expects a CSV anywhere in container FS matching expected_table.csv
#
# Outputs:
#   - grading_YYYYMMDD_HHMMSS.log
#   - grades.csv: student,project01,project02,total
#
# IMPORTANT:
#   - All log messages go to STDERR and to LOG_FILE (tee), never to STDOUT.
#   - Only "score|reason" is printed to STDOUT for parsing.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TESTDATA_DIR="$SCRIPT_DIR/testdata"
P2_HTML="$TESTDATA_DIR/sample.html"
P2_EXPECTED="$TESTDATA_DIR/expected_table.csv"

LOG_FILE="$SCRIPT_DIR/grading_$(date +%Y%m%d_%H%M%S).log"
GRADES_CSV="$SCRIPT_DIR/grades.csv"

TIME_LIMIT=20

# --- summary counters ---
P1_PASS=0; P1_FAIL=0
P2_PASS=0; P2_FAIL=0
TOTAL_STUDENTS=0

SUM_P1=0; SUM_P2=0; SUM_TOTAL=0
MIN_P1=999; MIN_P2=999; MIN_TOTAL=999
MAX_P1=0;   MAX_P2=0;   MAX_TOTAL=0

# Log to terminal + log file, but ONLY on STDERR so it doesn't pollute $(...)
log() { echo "$1" | tee -a "$LOG_FILE" >&2; }

normalize_stream() { sed 's/\r//g' | sed 's/[[:space:]]*$//'; }
normalize_file() { normalize_stream < "$1"; }

run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@"
  fi
}

cleanup_container() { docker rm -f "$1" >/dev/null 2>&1 || true; }
cleanup_image() { docker rmi -f "$1" >/dev/null 2>&1 || true; }

build_image() {
  local image="$1" path="$2"
  docker build -t "$image" "$path" >>"$LOG_FILE" 2>&1
}

# ----------------------------- Project01 test ------------------------------
# returns 0 on pass, 1 on fail
test_project01() {
  local image="$1"
  local expected="Hello World Aditya"

  local raw actual
  raw="$(run_with_timeout "$TIME_LIMIT" docker run --rm "$image" Aditya 2>&1 || true)"
  actual="$(echo "$raw" | normalize_stream)"

  log "DEBUG Raw Output: $raw"

  [[ "$actual" == "$expected" ]]
}

# ----------------------------- Project02 test ------------------------------
# returns 0 on pass, 1 on fail
test_project02() {
  local image="$1"

  if [[ ! -f "$P2_HTML" || ! -f "$P2_EXPECTED" ]]; then
    log "ERROR: grader missing testdata (sample.html or expected_table.csv)"
    return 1
  fi

  local expected
  expected="$(normalize_file "$P2_EXPECTED")"

  local attempt
  for attempt in 1 2; do
    local container="p2_${attempt}_${RANDOM}_$$"
    local tmpdir="$SCRIPT_DIR/tmp_${container}"
    mkdir -p "$tmpdir"

    log "Running Project02 Test (attempt $attempt)..."

    if [[ "$attempt" -eq 1 ]]; then
      docker create --name "$container" \
        -v "$P2_HTML":/app/input.html \
        "$image" input.html >/dev/null 2>&1 || true
    else
      docker create --name "$container" \
        -v "$P2_HTML":/app/input.html \
        "$image" input.html output.csv >/dev/null 2>&1 || true
    fi

    if ! docker inspect "$container" >/dev/null 2>&1; then
      log "Project02: container create failed"
      rm -rf "$tmpdir" >/dev/null 2>&1 || true
      return 1
    fi

    docker start "$container" >/dev/null 2>&1 || true
    run_with_timeout "$TIME_LIMIT" docker wait "$container" >/dev/null 2>&1 || true

    local logs
    logs="$(docker logs "$container" 2>&1 | normalize_stream)"

    # Copy lots of possible locations
    docker cp "$container":/app/. "$tmpdir/app" >/dev/null 2>&1 || true
    docker cp "$container":/. "$tmpdir/rootfs" >/dev/null 2>&1 || true

    cleanup_container "$container"

    local found_any=0 matched=0 f
    shopt -s nullglob
    for f in \
      "$tmpdir/app"/*.csv "$tmpdir/app"/*/*.csv \
      "$tmpdir/rootfs"/*.csv "$tmpdir/rootfs"/*/*.csv \
      "$tmpdir/rootfs/app"/*.csv "$tmpdir/rootfs/app"/*/*.csv
    do
      [[ -f "$f" ]] || continue
      found_any=1

      local actual
      actual="$(normalize_file "$f")"
      if diff <(echo "$expected") <(echo "$actual") >/dev/null 2>&1; then
        matched=1
        log "Project02 PASS (matched $(basename "$f"))"
        break
      fi
    done
    shopt -u nullglob

    rm -rf "$tmpdir" >/dev/null 2>&1 || true

    if [[ "$matched" -eq 1 ]]; then
      return 0
    fi

    if [[ "$found_any" -eq 0 ]]; then
      log "No CSV found on attempt $attempt."
    else
      log "CSV found on attempt $attempt, but none matched expected."
    fi
    log "Logs:"
    echo "$logs" | tee -a "$LOG_FILE" >&2
  done

  return 1
}

# ----------------------------- Score wrapper ------------------------------
# Prints ONE line to STDOUT: "SCORE|REASON"
score_project() {
  local student="$1" project="$2" kind="$3"
  local path="$REPO_ROOT/$student/$project"
  local image="${student}_${project}_image"

  # Missing folder => -60 => 40
  if [[ ! -d "$path" ]]; then
    echo "40|FAIL (folder missing => -60)"
    return
  fi

  log ""
  log "Building $project..."
  if ! build_image "$image" "$path"; then
    log "Build FAILED"
    cleanup_image "$image"
    # Build fails => -40 => 60
    echo "60|FAIL (build failed => -40)"
    return
  fi
  log "Build SUCCESS"

  if [[ "$kind" == "p1" ]]; then
    log "Running Project01 Test..."
    if test_project01 "$image"; then
      cleanup_image "$image"
      echo "100|PASS"
    else
      cleanup_image "$image"
      echo "80|FAIL (wrong output => -20)"
    fi
  else
    log "Running Project02 Test..."
    if test_project02 "$image"; then
      cleanup_image "$image"
      echo "100|PASS"
    else
      cleanup_image "$image"
      echo "80|FAIL (wrong/missing CSV => -20)"
    fi
  fi
}

# ----------------------------- Main ------------------------------
log "Repository Root: $REPO_ROOT"
log "Log File: $LOG_FILE"
log "--------------------------------------------"

echo "student,project01,project02,total" > "$GRADES_CSV"

for student_path in "$REPO_ROOT"/*; do
  [[ -d "$student_path" ]] || continue
  student="$(basename "$student_path")"

  log ""
  log "============================================"
  log "Grading Student: $student"
  log "============================================"

  p1_raw="$(score_project "$student" "project01" "p1")"
  p1_line="$(printf '%s\n' "$p1_raw" | head -n 1)"
  p1_score="$(printf '%s' "$p1_line" | cut -d'|' -f1 | tr -cd '0-9')"
  p1_reason="$(printf '%s' "$p1_line" | cut -d'|' -f2-)"
  [[ -z "$p1_score" ]] && p1_score=0
  log "Project01: $p1_score - $p1_reason"

  p2_raw="$(score_project "$student" "project02" "p2")"
  p2_line="$(printf '%s\n' "$p2_raw" | head -n 1)"
  p2_score="$(printf '%s' "$p2_line" | cut -d'|' -f1 | tr -cd '0-9')"
  p2_reason="$(printf '%s' "$p2_line" | cut -d'|' -f2-)"
  [[ -z "$p2_score" ]] && p2_score=0
  log "Project02: $p2_score - $p2_reason"

  total=$((p1_score + p2_score))
  ((TOTAL_STUDENTS++))

  # PASS if score >= 80
  if [[ "$p1_score" -ge 80 ]]; then ((P1_PASS++)); else ((P1_FAIL++)); fi
  if [[ "$p2_score" -ge 80 ]]; then ((P2_PASS++)); else ((P2_FAIL++)); fi

  # score aggregates
  SUM_P1=$((SUM_P1 + p1_score))
  SUM_P2=$((SUM_P2 + p2_score))
  SUM_TOTAL=$((SUM_TOTAL + total))

  (( p1_score < MIN_P1 )) && MIN_P1=$p1_score
  (( p2_score < MIN_P2 )) && MIN_P2=$p2_score
  (( total    < MIN_TOTAL )) && MIN_TOTAL=$total

  (( p1_score > MAX_P1 )) && MAX_P1=$p1_score
  (( p2_score > MAX_P2 )) && MAX_P2=$p2_score
  (( total    > MAX_TOTAL )) && MAX_TOTAL=$total

  echo "$student,$p1_score,$p2_score,$total" | tee -a "$GRADES_CSV" >&2
done

# --- final summary ---
OVERALL_PASS=$((P1_PASS + P2_PASS))
OVERALL_FAIL=$((P1_FAIL + P2_FAIL))
OVERALL_TESTS=$((OVERALL_PASS + OVERALL_FAIL))

AVG_P1=0; AVG_P2=0; AVG_TOTAL=0
if [[ "$TOTAL_STUDENTS" -gt 0 ]]; then
  AVG_P1=$((SUM_P1 / TOTAL_STUDENTS))
  AVG_P2=$((SUM_P2 / TOTAL_STUDENTS))
  AVG_TOTAL=$((SUM_TOTAL / TOTAL_STUDENTS))
fi

log ""
log "============================================"
log "FINAL SUMMARY"
log "============================================"
log "Students graded: $TOTAL_STUDENTS"
log ""
log "Project01: PASS=$P1_PASS  FAIL=$P1_FAIL  (min=$MIN_P1 max=$MAX_P1 avg=$AVG_P1)"
log "Project02: PASS=$P2_PASS  FAIL=$P2_FAIL  (min=$MIN_P2 max=$MAX_P2 avg=$AVG_P2)"
log ""
log "Overall tests: $OVERALL_TESTS  PASS=$OVERALL_PASS  FAIL=$OVERALL_FAIL"
log "Totals (P1+P2): min=$MIN_TOTAL max=$MAX_TOTAL avg=$AVG_TOTAL"
log ""
log "Grades CSV: $GRADES_CSV"
log "Log File:  $LOG_FILE"
log "Grading Complete."
