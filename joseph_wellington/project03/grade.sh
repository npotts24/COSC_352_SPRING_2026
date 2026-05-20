#!/usr/bin/env bash
set -u

# Project 3 - Docker autograder (Bash only)
# Loops over student dirs, builds/runs project01 + project02 containers,
# compares output to expected, prints + logs results, cleans up images/containers.

LOG_FILE="grading.log"
TEST_DIR=".grader_tests"

# Write to screen AND log
log() {
  echo "$*" | tee -a "$LOG_FILE"
}

# Safe cleanup helper
cleanup_image() {
  local img="$1"
  docker rmi -f "$img" >/dev/null 2>&1 || true
}

# ---------- Setup ----------
: > "$LOG_FILE"
log "=== COSC 352 Autograder شروع (start) ==="
log "Timestamp: $(date)"
log ""

# Create local test fixtures (NO curl/wget needed)
mkdir -p "$TEST_DIR"

# A small HTML file with a simple table (Project 2 should parse ANY html table)
cat > "$TEST_DIR/sample_table.html" <<'HTML'
<html>
  <body>
    <table>
      <tr><th>Language</th><th>Type</th></tr>
      <tr><td>Python</td><td>High-level</td></tr>
      <tr><td>C</td><td>Low-level</td></tr>
    </table>
  </body>
</html>
HTML

# Expected CSV for the above table
# (If your Project 2 outputs slightly different formatting, adjust this.)
cat > "$TEST_DIR/expected_languages.csv" <<'CSV'
Language,Type
Python,High-level
C,Low-level
CSV

# ---------- Test Definitions ----------
# Project 1 test: run container and pass a name argument.
# Adjust expected output to match YOUR project01 program.
P1_ARG="Joseph"
P1_EXPECTED="Hello World! I mean... Hello Joseph!"

# ---------- Iterate students ----------
PASS_COUNT=0
FAIL_COUNT=0

# Loop over directories in current folder (students)
for student_dir in */ ; do
  # Skip obvious non-student dirs
  [[ "$student_dir" == "$TEST_DIR/" ]] && continue

  student="${student_dir%/}"

  p1_path="${student_dir}project01"
  p2_path="${student_dir}project02"

  log "----------------------------------------"
  log "Student: $student"

  # ---------- Project 01 ----------
  if [[ -f "$p1_path/Dockerfile" ]]; then
    img1="grader_${student}_p1"

    log "[P1] Building image from $p1_path ..."
    if docker build -t "$img1" "$p1_path" >/dev/null 2>&1; then
      # Run: (assumes container runs python script that uses argv)
      log "[P1] Running test..."
      out1="$(docker run --rm "$img1" "$P1_ARG" 2>/dev/null | tr -d '\r')"

      if echo "$out1" | grep -Fq "$P1_EXPECTED"; then
        log "[P1] PASS"
      else
        log "[P1] FAIL"
        log "     Expected to contain: $P1_EXPECTED"
        log "     Got: $out1"
        FAIL_COUNT=$((FAIL_COUNT+1))
      fi
    else
      log "[P1] FAIL (docker build failed)"
      FAIL_COUNT=$((FAIL_COUNT+1))
    fi

    cleanup_image "$img1"
  else
    log "[P1] SKIP (no Dockerfile found)"
  fi

  # ---------- Project 02 ----------
  if [[ -f "$p2_path/Dockerfile" ]]; then
    img2="grader_${student}_p2"

    log "[P2] Building image from $p2_path ..."
    if docker build -t "$img2" "$p2_path" >/dev/null 2>&1; then
      log "[P2] Running test..."

      # Run container, mount tests into /tests, run student script from /work
      # We run it in a mounted /work folder if needed.
      # Assumes student has read_html_table.py that writes languages.csv in current dir.
      run_out="$(docker run --rm \
        -v "$(pwd)/$p2_path":/work \
        -v "$(pwd)/$TEST_DIR":/tests \
        -w /work \
        "$img2" \
        python read_html_table.py /tests/sample_table.html 2>/dev/null | tr -d '\r')"

      # Check produced file exists and matches expected
      if [[ -f "$p2_path/languages.csv" ]]; then
        if diff -u "$TEST_DIR/expected_languages.csv" "$p2_path/languages.csv" >/dev/null 2>&1; then
          log "[P2] PASS"
        else
          log "[P2] FAIL (CSV differs)"
          log "----- expected -----"
          sed -n '1,20p' "$TEST_DIR/expected_languages.csv" | tee -a "$LOG_FILE"
          log "----- got -----"
          sed -n '1,20p' "$p2_path/languages.csv" | tee -a "$LOG_FILE"
          FAIL_COUNT=$((FAIL_COUNT+1))
        fi
      else
        log "[P2] FAIL (languages.csv not created)"
        log "     Run output: $run_out"
        FAIL_COUNT=$((FAIL_COUNT+1))
      fi

      # Clean up generated file so reruns are clean
      rm -f "$p2_path/languages.csv" >/dev/null 2>&1 || true
    else
      log "[P2] FAIL (docker build failed)"
      FAIL_COUNT=$((FAIL_COUNT+1))
    fi

    cleanup_image "$img2"
  else
    log "[P2] SKIP (no Dockerfile found)"
  fi

  # If both weren’t hard fails, count as processed
  PASS_COUNT=$((PASS_COUNT+1))
done

log "----------------------------------------"
log "DONE."
log "Processed dirs: $PASS_COUNT"
log "Failures: $FAIL_COUNT"
log "Log saved to: $LOG_FILE"
