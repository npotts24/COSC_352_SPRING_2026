#!/usr/bin/env bash
set -eu

# Docker project grader.
# Edit the config block below for future assignments.
# Default coverage is included for project01 and project02.

# Student submissions live here unless you pass a different root directory.
ROOT_DIR="${1:-$(pwd)}"

# Generated test specs and logs are written here.
ARTIFACT_DIR="/Users/marco/Documents"

# Projects to look for under each student directory.
# Example expected layout:
#   ROOT_DIR/student_a/project01/Dockerfile
#   ROOT_DIR/student_a/project02/Dockerfile
PROJECTS=(project01 project02)

# Docker/runtime settings.
IMAGE_PREFIX="autograde"
RUN_TIMEOUT="20"
STARTUP_WAIT="3"
HOST_PORT_BASE="18080"
DOCKERFILE_NAME="Dockerfile"

# Test spec files. If these do not exist, example files are created automatically.
PROJECT01_TEST_FILE="$ARTIFACT_DIR/project01.tests"
PROJECT02_TEST_FILE="$ARTIFACT_DIR/project02.tests"

timestamp() {
  printf '%s_%s_%s\n' "$$" "$SECONDS" "$RANDOM"
}

LOGFILE="$ARTIFACT_DIR/grading_result_$(timestamp).log"
exec > >(tee -a "$LOGFILE") 2>&1

info() { printf '[INFO] %s\n' "$1"; }
pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; }

wait_seconds() {
  local duration="$1"
  local start="$SECONDS"
  while (( SECONDS - start < duration )); do
    :
  done
}

normalize_file() {
  sed -e 's/\r$//' -e 's/[[:space:]]*$//' -e :a -e '/^$/{$d;N;ba;}' "$1"
}

compare_output() {
  local expected="$1"
  local actual="$2"
  local mode="${3:-exact}"
  local prefix="$ARTIFACT_DIR/.grade_$(timestamp)_$$"
  local expected_file="${prefix}.expected"
  local actual_file="${prefix}.actual"
  local expected_normalized="${prefix}.expected.normalized"
  local actual_normalized="${prefix}.actual.normalized"

  printf '%s\n' "$expected" > "$expected_file"
  printf '%s\n' "$actual" > "$actual_file"

  if [[ "$mode" = "contains" ]]; then
    if [[ "$actual" == *"$expected"* ]]; then
      return 0
    fi
    info "Expected output to contain:"
    sed 's/^/  /' "$expected_file"
    info "Actual output:"
    sed 's/^/  /' "$actual_file"
    return 1
  fi

  normalize_file "$expected_file" > "$expected_normalized"
  normalize_file "$actual_file" > "$actual_normalized"

  if diff -u "$expected_normalized" "$actual_normalized" >/dev/null 2>&1; then
    return 0
  fi

  info "Expected:"
  sed 's/^/  /' "$expected_normalized"
  info "Actual:"
  sed 's/^/  /' "$actual_normalized"
  diff -u "$expected_normalized" "$actual_normalized" | sed 's/^/  /'
  return 1
}

ensure_example_test_files() {
  if [[ ! -f "$PROJECT01_TEST_FILE" ]]; then
    cat > "$PROJECT01_TEST_FILE" <<'EOF'
# project01 example tests
# Format:
#   test_type|run_args|input|expected_output|match_mode
# test_type:
#   stdin  - pipe input to container stdin
#   args   - pass run_args to docker run after image name
#   http   - run container in background, where run_args is the container port
# match_mode:
#   exact (default) or contains
stdin||hello world|hello world|exact
EOF
  fi

  if [[ ! -f "$PROJECT02_TEST_FILE" ]]; then
    cat > "$PROJECT02_TEST_FILE" <<'EOF'
# project02 example tests
# Format:
#   test_type|run_args|input|expected_output|match_mode
args|--version||v1.0|contains
http|80|GET /|OK|contains
EOF
  fi
}

tests_file_for_project() {
  case "$1" in
    project01) printf '%s\n' "$PROJECT01_TEST_FILE" ;;
    project02) printf '%s\n' "$PROJECT02_TEST_FILE" ;;
    *)
      printf '%s/%s.tests\n' "$ARTIFACT_DIR" "$1"
      ;;
  esac
}

build_image() {
  local project_path="$1"
  local image_tag="$2"

  if [[ ! -f "$project_path/$DOCKERFILE_NAME" ]]; then
    info "Skipping $project_path: no $DOCKERFILE_NAME"
    return 1
  fi

  info "Building image $image_tag from $project_path"
  docker build -t "$image_tag" "$project_path"
}

run_stdin_test() {
  local image_tag="$1"
  local run_args="$2"
  local input_text="$3"
  printf '%s' "$input_text" | timeout "$RUN_TIMEOUT" docker run --rm -i "$image_tag" $run_args 2>&1 || true
}

run_args_test() {
  local image_tag="$1"
  local run_args="$2"
  timeout "$RUN_TIMEOUT" docker run --rm "$image_tag" $run_args 2>&1 || true
}

run_http_test() {
  local image_tag="$1"
  local container_port="$2"
  local request_text="$3"
  local host_port="$4"
  local container_name="$5"
  local method
  local path
  local actual

  method="$(printf '%s\n' "$request_text" | awk '{print $1}')"
  path="$(printf '%s\n' "$request_text" | awk '{print $2}')"
  [[ -n "$path" ]] || path="/"

  docker run -d --rm --name "$container_name" -p "$host_port:${container_port:-80}" "$image_tag" >/dev/null
  wait_seconds "$STARTUP_WAIT"
  actual="$(timeout "$RUN_TIMEOUT" curl -s -X "${method:-GET}" "http://127.0.0.1:${host_port}${path}" 2>&1 || true)"
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  printf '%s\n' "$actual"
}

run_testcase() {
  local image_tag="$1"
  local test_spec="$2"
  local student_name="$3"
  local project_name="$4"
  local host_port="$5"
  local container_name="$6"
  local test_type
  local run_args
  local input_text
  local expected
  local match_mode
  local actual

  IFS='|' read -r test_type run_args input_text expected match_mode <<< "$test_spec"
  match_mode="${match_mode:-exact}"

  case "$test_type" in
    stdin)
      actual="$(run_stdin_test "$image_tag" "$run_args" "$input_text")"
      ;;
    args)
      actual="$(run_args_test "$image_tag" "$run_args")"
      ;;
    http)
      actual="$(run_http_test "$image_tag" "$run_args" "$input_text" "$host_port" "$container_name")"
      ;;
    *)
      actual="UNSUPPORTED_TEST_TYPE:$test_type"
      ;;
  esac

  if compare_output "$expected" "$actual" "$match_mode"; then
    pass "$student_name/$project_name: ($test_type $run_args) passed"
    return 0
  fi

  fail "$student_name/$project_name: ($test_type $run_args) failed"
  return 1
}

grade_project() {
  local student_dir="$1"
  local project_name="$2"
  local student_name="$3"
  local project_path="$student_dir/$project_name"
  local tests_file
  local image_tag
  local test_spec
  local total=0
  local passed=0
  local host_port
  local container_name

  if [[ ! -d "$project_path" ]]; then
    info "Skipping $student_name/$project_name: directory not found"
    return
  fi

  image_tag="${IMAGE_PREFIX}_${student_name}_${project_name}"
  if ! build_image "$project_path" "$image_tag"; then
    fail "$student_name/$project_name: build failed"
    STUDENT_FAILED_PROJECTS=$((STUDENT_FAILED_PROJECTS + 1))
    TOTAL_FAILED_PROJECTS=$((TOTAL_FAILED_PROJECTS + 1))
    return
  fi

  tests_file="$(tests_file_for_project "$project_name")"
  if [[ ! -f "$tests_file" ]]; then
    info "Skipping $student_name/$project_name: no test spec file at $tests_file"
    docker image rm -f "$image_tag" >/dev/null 2>&1 || true
    return
  fi

  while IFS= read -r test_spec; do
    [[ -n "$test_spec" ]] || continue
    case "$test_spec" in
      \#*) continue ;;
    esac

    total=$((total + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    host_port=$((HOST_PORT_BASE + TOTAL_TESTS))
    container_name="${IMAGE_PREFIX}_${student_name}_${project_name}_${total}"

    if run_testcase "$image_tag" "$test_spec" "$student_name" "$project_name" "$host_port" "$container_name"; then
      passed=$((passed + 1))
      TOTAL_PASSED_TESTS=$((TOTAL_PASSED_TESTS + 1))
    else
      TOTAL_FAILED_TESTS=$((TOTAL_FAILED_TESTS + 1))
    fi
  done < "$tests_file"

  info "$student_name/$project_name: $passed/$total tests passed"

  if [[ "$total" -gt 0 && "$passed" -eq "$total" ]]; then
    STUDENT_PASSED_PROJECTS=$((STUDENT_PASSED_PROJECTS + 1))
    TOTAL_PASSED_PROJECTS=$((TOTAL_PASSED_PROJECTS + 1))
  else
    STUDENT_FAILED_PROJECTS=$((STUDENT_FAILED_PROJECTS + 1))
    TOTAL_FAILED_PROJECTS=$((TOTAL_FAILED_PROJECTS + 1))
  fi

  docker image rm -f "$image_tag" >/dev/null 2>&1 || true
}

main() {
  local student_dir
  local student_name
  local project_name

  ensure_example_test_files

  TOTAL_STUDENTS=0
  TOTAL_TESTS=0
  TOTAL_PASSED_TESTS=0
  TOTAL_FAILED_TESTS=0
  TOTAL_PASSED_PROJECTS=0
  TOTAL_FAILED_PROJECTS=0

  info "Starting grading run"
  info "Student root: $ROOT_DIR"
  info "Artifacts: $ARTIFACT_DIR"
  info "Log file: $LOGFILE"

  while IFS= read -r student_dir; do
    [[ -n "$student_dir" ]] || continue
    student_name="${student_dir##*/}"
    TOTAL_STUDENTS=$((TOTAL_STUDENTS + 1))
    STUDENT_PASSED_PROJECTS=0
    STUDENT_FAILED_PROJECTS=0

    info "------------------------------------------------------------"
    info "Grading student: $student_name"

    for project_name in "${PROJECTS[@]}"; do
      grade_project "$student_dir" "$project_name" "$student_name"
    done

    info "$student_name summary: passed projects=$STUDENT_PASSED_PROJECTS failed projects=$STUDENT_FAILED_PROJECTS"
  done < <(find "$ROOT_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

  info "============================================================"
  info "Final summary"
  info "Students graded: $TOTAL_STUDENTS"
  info "Projects passed: $TOTAL_PASSED_PROJECTS"
  info "Projects failed: $TOTAL_FAILED_PROJECTS"
  info "Tests passed: $TOTAL_PASSED_TESTS"
  info "Tests failed: $TOTAL_FAILED_TESTS"
}

main "$@"
