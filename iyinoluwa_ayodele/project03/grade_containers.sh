
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
TEST_ROOT="$ROOT_DIR/grading_tests"
LOG_DIR="$ROOT_DIR/grading_logs"
mkdir -p "$LOG_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/grade_${TIMESTAMP}.log"

DEFAULT_PROJECTS=("project01" "project02")

DEFAULT_TIMEOUT=10

function usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --root DIR             Root directory containing student folders (default: script location)
  --projects "p1 p2"     Space-separated list of project folder names (default: project01 project02)
  --students "s1 s2"     Space-separated list of students to grade (default: all student dirs)
  --timeout SECONDS      Timeout per test run (default: $DEFAULT_TIMEOUT)
  --help                 Print this help message

Test data must exist under: $TEST_ROOT
See $TEST_ROOT/README.md for expected layout.
EOF
}

function die() {
  echo "ERROR: $*" >&2
  exit 1
}

function log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') | $*"
}

exec > >(tee -a "$LOG_FILE") 2>&1

ROOT="$ROOT_DIR"
PROJECTS=()
STUDENTS=()
TIMEOUT_SECONDS=$DEFAULT_TIMEOUT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="$2"; shift 2;;
    --projects)
      IFS=' ' read -r -a PROJECTS <<< "$2"; shift 2;;
    --students)
      IFS=' ' read -r -a STUDENTS <<< "$2"; shift 2;;
    --timeout)
      TIMEOUT_SECONDS="$2"; shift 2;;
    --help|-h)
      usage; exit 0;;
    *)
      die "Unknown option: $1";
  esac
done

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
  PROJECTS=("${DEFAULT_PROJECTS[@]}")
fi

# Ensure root is absolute
ROOT="$(cd "$ROOT" && pwd)"

function discover_students() {
  local base="$1"

  # Exclude known non-student directories (grading artifacts, git, etc.)
  find "$base" -maxdepth 1 -mindepth 1 -type d \
    \( -name "grading_tests" -o -name "grading_logs" -o -name ".git" \) -prune -o -print | sort
}

function list_tests_for_project() {
  local project="$1"
  local project_test_dir="$TEST_ROOT/$project"
  if [[ ! -d "$project_test_dir" ]]; then
    return 0
  fi

  find "$project_test_dir" -mindepth 1 -maxdepth 1 -type d -print | sort
}

function run_test_case() {
  local student="$1"
  local project="$2"
  local test_dir="$3"
  local image_tag="$4"
  local container_name="$5"

  local input_file="$test_dir/input.txt"
  local expected_file="$test_dir/expected.txt"
  local args_file="$test_dir/args.txt"

  if [[ ! -f "$expected_file" ]]; then
    log "WARN: Missing expected output for $project test $(basename "$test_dir"). Skipping."
    return 1
  fi

  
  local run_cmd=(docker run --rm --name "$container_name")
  if [[ -f "$args_file" ]]; then
    # Treat each line in args.txt as a separate argument
    mapfile -t extra_args < <(sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' "$args_file")
    for arg in "${extra_args[@]}"; do
      run_cmd+=("$arg")
    done
  fi


  run_cmd+=("$image_tag")

  local output_file
  output_file=$(mktemp)

  local status=0
  log "--> Running test: student=$student project=$project test=$(basename "$test_dir")"

  if [[ -f "$input_file" ]]; then
    if ! timeout "$TIMEOUT_SECONDS" "${run_cmd[@]}" <"$input_file" >"$output_file" 2>&1; then
      status=1
    fi
  else
    if ! timeout "$TIMEOUT_SECONDS" "${run_cmd[@]}" >"$output_file" 2>&1; then
      status=1
    fi
  fi

  local diff_output
  if ! diff -u "$expected_file" "$output_file" > /dev/null 2>&1; then
    status=1
    diff_output=$(diff -u "$expected_file" "$output_file" || true)
  fi

  if [[ $status -eq 0 ]]; then
    log "PASS: $student/$project/$(basename "$test_dir")"
    ((PASS_COUNT++))
  else
    log "FAIL: $student/$project/$(basename "$test_dir")"
    if [[ -n "$diff_output" ]]; then
      log "--- diff (expected vs actual) ---"
      echo "$diff_output" | sed 's/^/    /'
      log "-------------------------------"
    else
      log "(No diff available; the container may have timed out or crashed.)"
    fi
    ((FAIL_COUNT++))
  fi

  
  docker rm -f "$container_name" > /dev/null 2>&1 || true

  rm -f "$output_file"
}


log "Starting grading run"
log "Root directory: $ROOT"
log "Test root: $TEST_ROOT"
log "Projects: ${PROJECTS[*]}"
log "Timeout per test: ${TIMEOUT_SECONDS}s"

STUDENT_DIRS=()
if [[ ${#STUDENTS[@]} -gt 0 ]]; then
  for s in "${STUDENTS[@]}"; do
    STUDENT_DIRS+=("$ROOT/$s")
  done
else
  mapfile -t STUDENT_DIRS < <(discover_students "$ROOT")
fi

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

for student_path in "${STUDENT_DIRS[@]}"; do
  student_name=$(basename "$student_path")
  log "\n=== Grading student: $student_name ==="

  if [[ ! -d "$student_path" ]]; then
    log "WARN: student directory not found: $student_path"
    continue
  fi

  for project in "${PROJECTS[@]}"; do
    project_path="$student_path/$project"

    if [[ ! -d "$project_path" ]]; then
      log "WARN: missing project directory: $project_path"
      continue
    fi

    image_tag="grader_${student_name}_${project}"
    container_name="grader_${student_name}_${project}_run"

    log "Building image for $student_name/$project (image: $image_tag)"

    if ! docker build -q -t "$image_tag" "$project_path"; then
      log "FAIL: docker build failed for $student_name/$project"
      ((FAIL_COUNT++))
      continue
    fi

    mapfile -t test_dirs < <(list_tests_for_project "$project")
    if [[ ${#test_dirs[@]} -eq 0 ]]; then
      log "WARN: no tests found for project $project (expected under $TEST_ROOT/$project)"
    fi

    for test_dir in "${test_dirs[@]}"; do
      ((TOTAL_COUNT++))
      run_test_case "$student_name" "$project" "$test_dir" "$image_tag" "$container_name"
    done

    log "Cleaning up image: $image_tag"
    docker rmi -f "$image_tag" > /dev/null 2>&1 || true
  done

  log "Finished grading $student_name"
done



log "\n=== Grading Summary ==="
log "Total tests run: $TOTAL_COUNT"
log "Passed: $PASS_COUNT"
log "Failed: $FAIL_COUNT"

if [[ $FAIL_COUNT -eq 0 ]]; then
  log "All tests passed!"
else
  log "Some tests failed. See log: $LOG_FILE"
fi
