

set -u  


ROOT="${1:-.}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="grading_${TIMESTAMP}.log"

# All output goes to terminal AND log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Docker safety/timeouts
BUILD_TIMEOUT="120s"
RUN_TIMEOUT="8s"
HTTP_TIMEOUT="5"
CLEAN_IMAGES=1  

# Scoring/deductions
START_SCORE=100
DEDUCT_NON_FUNCTIONAL=30
DEDUCT_MISSING_REQ=10
DEDUCT_POOR_READABILITY=10
DEDUCT_POOR_DESIGN=10
DEDUCT_NO_VALIDATION=10
DEDUCT_BAD_ERROR_HANDLING=10
DEDUCT_DISALLOWED_TOOLS=30

# Summary counters
TOTAL_STUDENTS=0
TOTAL_PROJECTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Internal arrays (tests are built at runtime in configure_tests)
# We'll store tests as "PROJECT|MODE|INPUT|EXPECTED|DESC"
TESTCASES=()

### ----------------------------
### Utility helpers
### ----------------------------

hr() { printf '%*s\n' "${COLUMNS:-100}" '' | tr ' ' '-'; }

trim_ws() {
  # Normalize output: remove CR, trim trailing spaces, drop leading/trailing blank lines
  # Allowed tools: sed
  sed -e 's/\r$//' -e 's/[[:space:]]\+$//' \
      -e ':a;/^\n*$/{$d;N;ba' -e '}' \
      -e '1{/^$/d;}' 2>/dev/null
}

safe_name() {
  # Make a string docker-tag safe-ish
  echo "$1" | sed 's/[^a-zA-Z0-9_.-]/_/g' | tr '[:upper:]' '[:lower:]'
}

cleanup_container() {
  local cname="$1"
  docker rm -f "$cname" >/dev/null 2>&1 || true
}

cleanup_image() {
  local img="$1"
  if [[ "${CLEAN_IMAGES}" -eq 1 ]]; then
    docker rmi -f "$img" >/dev/null 2>&1 || true
  fi
}

compare_output() {
  # $1 actual_file, $2 expected_file
  diff -u "$2" "$1" >/dev/null 2>&1
}



configure_tests() {
  TESTCASES=()


  TESTCASES+=("project01|args|Mal|Hello World Mal|P01: prints Hello World <name> using CLI arg")
  TESTCASES+=("project01|args|Ada|Hello World Ada|P01: handles different name")

  # ---- Project 02 (placeholder examples; replace with real tests) ----
  # If P02 is stdin-based:
  TESTCASES+=("project02|stdin|2 3|5|P02: sums two numbers from stdin (example)")
  TESTCASES+=("project02|stdin|10 7|17|P02: sums another pair (example)")


}

# Optional per-project HTTP port (only used when MODE=http)
http_port_for_project() {
  case "$1" in
    project02) echo "8080" ;;   # change if needed
    *) echo "8080" ;;
  esac
}

### ----------------------------
### Project discovery (EDIT HERE IF YOUR REPO LAYOUT CHANGES)
### ----------------------------

discover_projects() {

  local root="$1"

  find "$root" -type f -name Dockerfile 2>/dev/null \
    | awk -F/ '
      {
        # project folder is parent of Dockerfile
        proj_path=$0
        sub(/\/Dockerfile$/, "", proj_path)
        n=split(proj_path, parts, "/")
        project=parts[n]
        student=parts[n-1]
        # only grade projects we care about
        if (project=="project01" || project=="project02") {
          printf "%s|%s|%s\n", student, project, proj_path
        }
      }' \
    | sort -u
}

### ----------------------------
### Docker build/run + test runners
### ----------------------------

build_image() {
  local proj_path="$1"
  local img="$2"

  echo "[BUILD] $img from $proj_path"
  if ! timeout "$BUILD_TIMEOUT" docker build -t "$img" "$proj_path" >/dev/null 2>&1; then
    echo "[ERROR] Build failed: $img"
    return 1
  fi
  return 0
}

run_testcase_args() {
  local img="$1"
  local input="$2"
  local actual_file="$3"

  # Run container with CLI args
  if ! timeout "$RUN_TIMEOUT" docker run --rm "$img" $input >"$actual_file" 2>/dev/null; then
    return 1
  fi
  return 0
}

run_testcase_stdin() {
  local img="$1"
  local input="$2"
  local actual_file="$3"

  # Pipe input to stdin
  if ! printf "%s" "$input" \
      | timeout "$RUN_TIMEOUT" docker run --rm -i "$img" >"$actual_file" 2>/dev/null; then
    return 1
  fi
  return 0
}

run_testcase_http() {
  local img="$1"
  local project="$2"
  local path="$3"
  local actual_file="$4"

  local port
  port="$(http_port_for_project "$project")"

  # Run detached, map to random host port
  local cname="grade_$(safe_name "$img")_$$"
  cleanup_container "$cname"

  if ! docker run -d --rm --name "$cname" -p 0:"$port" "$img" >/dev/null 2>&1; then
    cleanup_container "$cname"
    return 1
  fi

  # Determine mapped host port
  local host_port
  host_port="$(docker port "$cname" "$port/tcp" 2>/dev/null | sed 's/.*:\([0-9]\+\)$/\1/')"

  if [[ -z "${host_port:-}" ]]; then
    cleanup_container "$cname"
    return 1
  fi

  # Give it a moment to start (no sleep tool requested; use a tiny timeout loop with curl)
  # Try up to ~2 seconds total (10 tries * 0.2s approx is not possible without sleep;
  # we’ll just try a few quick curls and accept some failures gracefully.)
  timeout "$RUN_TIMEOUT" curl -sS --max-time "$HTTP_TIMEOUT" "http://127.0.0.1:${host_port}${path}" >"$actual_file" 2>/dev/null
  local rc=$?

  cleanup_container "$cname"
  return "$rc"
}

### ----------------------------
### Grading logic per student/project
### ----------------------------

grade_one_project() {
  local student="$1"
  local project="$2"
  local proj_path="$3"

  TOTAL_PROJECTS=$((TOTAL_PROJECTS+1))

  local img="c352_$(safe_name "$student")_${project}_$TIMESTAMP"
  local score="$START_SCORE"
  local passed=1

  hr
  echo "[STUDENT] $student"
  echo "[PROJECT] $project"
  echo "[PATH]    $proj_path"
  echo "[IMAGE]   $img"
  hr

  # Basic required files check (you can expand this)
  if [[ ! -f "$proj_path/Dockerfile" ]]; then
    echo "[FAIL] Missing Dockerfile"
    score=$((score-DEDUCT_MISSING_REQ))
    echo "[SCORE] $score"
    TOTAL_FAILED=$((TOTAL_FAILED+1))
    return 0
  fi

  # Build
  if ! build_image "$proj_path" "$img"; then
    score=$((score-DEDUCT_NON_FUNCTIONAL))
    passed=0
    echo "[DEDUCT] -$DEDUCT_NON_FUNCTIONAL (non-functional: build failed)"
    echo "[SCORE]  $score"
    cleanup_image "$img"
    TOTAL_FAILED=$((TOTAL_FAILED+1))
    return 0
  fi

  # Run tests for this project
  local any_tests=0
  local test_failures=0
  local test_total=0

  for tc in "${TESTCASES[@]}"; do
    IFS='|' read -r tc_proj tc_mode tc_input tc_expected tc_desc <<<"$tc"
    [[ "$tc_proj" != "$project" ]] && continue

    any_tests=1
    test_total=$((test_total+1))

    echo
    echo "[TEST] $tc_desc"
    echo "       mode=$tc_mode input='$tc_input' expected='$tc_expected'"

    local tmp_actual tmp_expected
    tmp_actual="$(mktemp)"
    tmp_expected="$(mktemp)"
    printf "%s\n" "$tc_expected" >"$tmp_expected"

    # Execute based on mode
    local run_ok=0
    case "$tc_mode" in
      args)
        run_testcase_args "$img" "$tc_input" "$tmp_actual" || run_ok=1
        ;;
      stdin)
        run_testcase_stdin "$img" "$tc_input" "$tmp_actual" || run_ok=1
        ;;
      http)
        run_testcase_http "$img" "$project" "$tc_input" "$tmp_actual" || run_ok=1
        ;;
      *)
        echo "[ERROR] Unknown test mode: $tc_mode"
        run_ok=1
        ;;
    esac

    if [[ "$run_ok" -ne 0 ]]; then
      echo "[FAIL] Container did not run correctly for this test (timeout/crash/etc.)"
      test_failures=$((test_failures+1))
      rm -f "$tmp_actual" "$tmp_expected"
      continue
    fi

    # Normalize before diff
    local norm_actual norm_expected
    norm_actual="$(mktemp)"
    norm_expected="$(mktemp)"
    trim_ws <"$tmp_actual" >"$norm_actual"
    trim_ws <"$tmp_expected" >"$norm_expected"

    if compare_output "$norm_actual" "$norm_expected"; then
      echo "[PASS]"
    else
      echo "[FAIL] Output mismatch"
      echo "------ ACTUAL ------"
      cat "$norm_actual"
      echo "----- EXPECTED -----"
      cat "$norm_expected"
      test_failures=$((test_failures+1))
    fi

    rm -f "$tmp_actual" "$tmp_expected" "$norm_actual" "$norm_expected"
  done

  if [[ "$any_tests" -eq 0 ]]; then
    echo "[WARN] No tests configured for $project"
    score=$((score-DEDUCT_NO_VALIDATION))
    echo "[DEDUCT] -$DEDUCT_NO_VALIDATION (no validation/tests configured)"
    passed=0
  else
    echo
    echo "[RESULT] tests: $((test_total-test_failures))/$test_total passed"
    if [[ "$test_failures" -gt 0 ]]; then
      # Deduct for missing requirements/incorrect behavior (simple policy)
      score=$((score-DEDUCT_MISSING_REQ))
      echo "[DEDUCT] -$DEDUCT_MISSING_REQ (failed one or more required tests)"
      passed=0
    fi
  fi

  # Cleanup
  cleanup_image "$img"

  echo "[SCORE] $score"

  if [[ "$passed" -eq 1 ]]; then
    TOTAL_PASSED=$((TOTAL_PASSED+1))
  else
    TOTAL_FAILED=$((TOTAL_FAILED+1))
  fi

  return 0
}

### ----------------------------
### Main
### ----------------------------

main() {
  echo "=== Docker Autograder ==="
  echo "Root:     $ROOT"
  echo "Log file: $LOG_FILE"
  echo

  configure_tests

  # Gather projects
  mapfile -t items < <(discover_projects "$ROOT")

  if [[ "${#items[@]}" -eq 0 ]]; then
    echo "[ERROR] No Dockerfile submissions found for project01/project02 under: $ROOT"
    echo "        Adjust discover_projects() to match your repo layout."
    exit 1
  fi

  # Iterate
  local last_student=""
  for line in "${items[@]}"; do
    IFS='|' read -r student project proj_path <<<"$line"
    if [[ "$student" != "$last_student" ]]; then
      TOTAL_STUDENTS=$((TOTAL_STUDENTS+1))
      last_student="$student"
    fi
    grade_one_project "$student" "$project" "$proj_path"
  done

  # Final summary
  hr
  echo "=== SUMMARY ==="
  echo "Students discovered: $TOTAL_STUDENTS"
  echo "Projects graded:     $TOTAL_PROJECTS"
  echo "Passed:             $TOTAL_PASSED"
  echo "Failed:             $TOTAL_FAILED"
  echo "Log:                $LOG_FILE"
  hr
}

main "$@"

