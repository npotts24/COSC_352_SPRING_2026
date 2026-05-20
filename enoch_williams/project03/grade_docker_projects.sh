#!/usr/bin/env bash
# Automated grader for student Docker container projects (Project01, Project02)
# Usage: scripts/grade_docker_projects.sh [workspace_root]

set -o pipefail

WORKSPACE_ROOT="${1:-.}"
STUDENT_FILTER="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$WORKSPACE_ROOT/grading_$(date +%Y%m%d_%H%M%S).log"
PROJECTS=(project01 project02)
BUILD_TIMEOUT=120
RUN_TIMEOUT=15
HTTP_READY_TIMEOUT=15

declare -A student_scores
declare -A student_tests_total
declare -A student_tests_passed

log(){ echo "$(date +'%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"; }

cleanup_container(){ local cid="$1"; if [ -n "$cid" ]; then docker rm -f "$cid" >/dev/null 2>&1 || true; fi }
cleanup_image(){ local img="$1"; if [ -n "$img" ]; then docker rmi -f "$img" >/dev/null 2>&1 || true; fi }

run_test_stdin(){ local image="$1" inputfile="$2"; timeout ${RUN_TIMEOUT}s docker run --rm "$image" <"$inputfile" 2>&1 || true; }

run_test_args(){ local image="$1" argsfile="$2"; local args; args=$(awk '{printf "%s ", $0}' "$argsfile"); timeout ${RUN_TIMEOUT}s docker run --rm "$image" $args 2>&1 || true; }

run_test_http(){ local image="$1" meta="$2" inputfile="$3"; local cname="grader_$(date +%s%N)"; local port mapping hostport path method body code url
  cid=$(docker run -d -P --name "$cname" "$image" 2>/dev/null) || { log "Failed to start container for HTTP test"; return 255; }
  trap 'cleanup_container "$cid"' RETURN
  # parse meta: expected keys: container_port, path, method
  container_port=$(awk -F= '/container_port/{print $2}' FS=';' RS=';' "$meta" 2>/dev/null || true)
  path=$(awk -F= '/path/{print $2}' FS=';' RS=';' "$meta" 2>/dev/null || true)
  method=$(awk -F= '/method/{print $2}' FS=';' RS=';' "$meta" 2>/dev/null || true)
  [ -z "$method" ] && method=GET
  [ -z "$path" ] && path=/
  if [ -n "$container_port" ]; then
    hostport=$(docker port "$cid" "$container_port" 2>/dev/null | sed -E 's/.*:([0-9]+)$/\1/' || true)
  else
    # try to pick the first published port
    hostport=$(docker port "$cid" | head -n1 | sed -E 's/.*:([0-9]+)$/\1/' || true)
  fi
  # wait for service
  local waited=0
  while [ -z "$hostport" ] || ! curl -s --max-time 2 "http://127.0.0.1:$hostport$path" >/dev/null 2>&1; do
    sleep 1; waited=$((waited+1)); if [ $waited -ge $HTTP_READY_TIMEOUT ]; then log "Service not ready on port $hostport"; break; fi
    hostport=$(docker port "$cid" "$container_port" 2>/dev/null | sed -E 's/.*:([0-9]+)$/\1/' || true)
  done
  url="http://127.0.0.1:$hostport$path"
  if [ "$method" = "POST" ]; then
    body=$(cat "$inputfile" 2>/dev/null || true)
    curl -s --max-time $RUN_TIMEOUT -X POST -d "$body" "$url" || true
  else
    curl -s --max-time $RUN_TIMEOUT "$url" || true
  fi
  rc=$?
  cleanup_container "$cid"; trap - RETURN
  return $rc
}

grade_student_project(){ local student_dir="$1" project="$2"
  local student_name; student_name=$(basename "$student_dir")
  local proj_dir="$student_dir/$project"
  local img_tag="grader_${student_name}_${project}"
  local project_tests_dir="$SCRIPT_DIR/tests/$project"
  student_tests_total["$student_name,${project}"]=0
  student_tests_passed["$student_name,${project}"]=0

  if [ ! -d "$proj_dir" ]; then
    log "[$student_name/$project] MISSING project dir"
    student_scores["$student_name,$project"]=0
    return
  fi

  if [ ! -f "$proj_dir/Dockerfile" ]; then
    log "[$student_name/$project] MISSING Dockerfile (-10 deduction)"
    # still try to continue but mark as non-functional
    student_scores["$student_name,$project"]=70
    return
  fi

  log "[$student_name/$project] Building image..."
  if ! timeout ${BUILD_TIMEOUT}s docker build -t "$img_tag" "$proj_dir" 2>&1 | tee -a "$LOGFILE"; then
    log "[$student_name/$project] Build failed. Marking non-functional (-30)"
    student_scores["$student_name,$project"]=$((100-30))
    return
  fi

  # If no tests defined, skip
  if [ ! -d "$project_tests_dir" ]; then
    log "[$student_name/$project] No tests defined for $project"
    student_scores["$student_name,$project"]=100
    cleanup_image "$img_tag"
    return
  fi

  # iterate tests (.input + .expected + optional .meta)
  for infile in "$project_tests_dir"/*.input; do
    [ -e "$infile" ] || break
    testname=$(basename "$infile" .input)
    expected="$project_tests_dir/$testname.expected"
    meta="$project_tests_dir/$testname.meta"
    method="stdin"
    if [ -f "$meta" ]; then
      method=$(awk -F= '/method/{print $2}' FS=';' RS=';' "$meta" 2>/dev/null || true)
      [ -z "$method" ] && method=stdin
    fi
    student_tests_total["$student_name,${project}"]=$((student_tests_total["$student_name,${project}"]+1))
    log "[$student_name/$project] Running test $testname (method=$method)"
    case "$method" in
      stdin)
        out=$(run_test_stdin "$img_tag" "$infile") || true
        ;;
      args)
        out=$(run_test_args "$img_tag" "$infile") || true
        ;;
      http)
        out=$(run_test_http "$img_tag" "$meta" "$infile" ) || true
        ;;
      *)
        log "Unknown method '$method' for test $testname"
        out=""
        ;;
    esac
    # write actual output to a temp file to diff
    tmpout=$(mktemp)
    printf "%s" "$out" > "$tmpout"
    if [ -f "$expected" ]; then
      if diff -u "$expected" "$tmpout" >/dev/null 2>&1; then
        log "[$student_name/$project] $testname: PASS"
        student_tests_passed["$student_name,${project}"]=$((student_tests_passed["$student_name,${project}"]+1))
      else
        log "[$student_name/$project] $testname: FAIL"
        log "--- Expected ---"; sed -n '1,200p' "$expected" | sed -n '1,50p' | tee -a "$LOGFILE"
        log "--- Actual ---"; sed -n '1,200p' "$tmpout" | sed -n '1,50p' | tee -a "$LOGFILE"
      fi
    else
      log "[$student_name/$project] $testname: NO expected file (skipping diff)"
    fi
    rm -f "$tmpout"
  done

  # scoring: correctness worth 40 points across tests; build/run non-functional handled earlier
  local total=${student_tests_total["$student_name,${project}"]:-0}
  local passed=${student_tests_passed["$student_name,${project}"]:-0}
  local correctness=40
  local deduct=0
  if [ $total -gt 0 ]; then
    deduct=$(( correctness * (total - passed) / total ))
  else
    deduct=0
  fi
  score=$((100 - deduct))
  student_scores["$student_name,$project"]=$score
  log "[$student_name/$project] Tests: $passed/$total, Score: $score"
  cleanup_image "$img_tag"
}

main(){
  log "Starting grading run. Workspace root: $WORKSPACE_ROOT"
  # iterate student directories (top-level directories only)
  for sd in "$WORKSPACE_ROOT"/*/; do
    [ -d "$sd" ] || continue
    student=$(basename "$sd")
    if [ -n "$STUDENT_FILTER" ] && [ "$student" != "$STUDENT_FILTER" ]; then
      continue
    fi
    # skip known non-student files
    if [ "$student" = "scripts" ] || [ "$student" = "tests" ]; then continue; fi
    log "Processing student: $student"
    for p in "${PROJECTS[@]}"; do
      grade_student_project "$sd" "$p"
    done
    log "Completed $student"
  done

  # summary
  log "--- Final Summary ---"
  for key in "${!student_scores[@]}"; do
    IFS=, read -r student project <<< "$key"
    score=${student_scores[$key]}
    log "$student / $project : $score"
  done
  log "Log file: $LOGFILE"
}

main "$@"
