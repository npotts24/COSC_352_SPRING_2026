#!/usr/bin/env bash
set -eu

# Simple automated grader for student Docker container projects
# - Builds images from each student's project directories
# - Runs tests with stdin/args/http modes
# - Compares output to expected output
# - Prints results to screen and logs to a timestamped logfile

# repository root
ROOT_DIR="$(pwd)"

# Use the specified student project directory to store tests and results.
# This ensures tests and grading output are always written to the requested
# location: /workspaces/COSC_352_SPRING_2026/abdul_quayyum_yussuf/project03
TEST_DIR="$ROOT_DIR/abdul_quayyum_yussuf/project03"
mkdir -p "$TEST_DIR/grading_tests" "$TEST_DIR/grading_results"

# If there are no test files present under the target directory, populate
# it with default example tests for project01 and project02.
if ! compgen -G "$TEST_DIR/grading_tests/*.tests" >/dev/null; then
  cat > "$TEST_DIR/grading_tests/project01.tests" <<'EOF'
# Project 01 tests
# Format: test_type|run_args|input|expected_output
stdin||hello world|hello world
EOF
  cat > "$TEST_DIR/grading_tests/project02.tests" <<'EOF'
# Project 02 tests
# Format: test_type|run_args|input|expected_output
args|--version||v1.0
http|80|GET /|OK
EOF
fi

# Place logs in the project03 results directory so instructor can find them
LOGFILE="$TEST_DIR/grading_results/grading_result_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Modify these lists to change which projects and tests are run
PROJECTS=(project01 project02)

# Example tests: each entry is a pipe-delimited string with fields:
# test_type|run_args|input|expected_output
# test_type: stdin | args | http
# - stdin: run_args are optional command to run inside container; input piped to container stdin
# - args: run_args are the command args given to container; input field is unused (can be empty)
# - http: run_args is the container exposed port (containerPort), input is HTTP path and method like "GET /"; expected is response body

project01_tests=(
  "stdin||hello world|hello world"  # example: container echoes stdin
)

project02_tests=(
  "args|--version||v1.0"            # example: container prints version with arg
  "http|80|GET /|OK"                # example: container serves HTTP 80 and returns 'OK' for GET /
)

info() { printf "[%s] %s\n" "INFO" "$1"; }
fail() { printf "[%s] %s\n" "FAIL" "$1"; }
pass() { printf "[%s] %s\n" "PASS" "$1"; }

normalize() {
  # trim trailing newlines and carriage returns
  printf "%s" "$1" | sed -e 's/\r$//' -e :a -e '/^$/{$d;};N;ba' || true
}

compare_output() {
  local expected="$1" actual="$2" mode="${3:-exact}"
  local tmp1 tmp2
  tmp1=$(mktemp)
  tmp2=$(mktemp)
  printf "%s" "$expected" > "$tmp1"
  printf "%s" "$actual" > "$tmp2"
  
  local result=1
  if [[ "$mode" == "contains" ]]; then
    # Check if actual output contains the expected string
    if [[ "$actual" == *"$expected"* ]]; then
      result=0
    fi
  else
    # Exact match (default)
    if diff -u "$tmp1" "$tmp2" >/dev/null 2>&1; then
      result=0
    fi
  fi
  
  if [ $result -eq 0 ]; then
    rm -f "$tmp1" "$tmp2"
    return 0
  else
    echo "--- expected ($mode)"; cat "$tmp1"; echo "--- actual"; cat "$tmp2"
    rm -f "$tmp1" "$tmp2"
    return 1
  fi
}

setup_project02_test_file() {
  # Create a minimal test HTML file with a table.
  # This simulates the Wikipedia table the student must parse.
  cat > /tmp/test_table.html <<'HTMLEOF'
<!DOCTYPE html>
<html>
<head><title>Test Table</title></head>
<body>
<h1>Programming Languages</h1>
<table>
<tr><th>Language</th><th>Year</th><th>Type</th></tr>
<tr><td>Python</td><td>1991</td><td>Interpreted</td></tr>
<tr><td>Java</td><td>1995</td><td>Compiled</td></tr>
<tr><td>JavaScript</td><td>1995</td><td>Interpreted</td></tr>
<tr><td>C</td><td>1972</td><td>Compiled</td></tr>
</table>
</body>
</html>
HTMLEOF
}

run_testcase() {
  local image="$1" test_spec="$2" student="$3" project="$4"
  IFS='|' read -r test_type run_args input expected mode <<< "$test_spec"
  mode="${mode:-exact}"  # default to exact matching if mode not specified
  local actual=""

  case "$test_type" in
    stdin)
      actual=$(printf "%s" "$input" | docker run --rm -i "$image" $run_args 2>&1 || true)
      ;;
    args)
      # Special handling for project02 tests that need input HTML file
      if [[ "$project" == "project02" && "$run_args" == *".html"* ]]; then
        setup_project02_test_file
        # Mount the test HTML file into the container and run it.
        # The program is the ENTRYPOINT, just pass the argument
        actual=$(docker run --rm -v /tmp/test_table.html:/tmp/test_table.html "$image" "$run_args" 2>&1 || true)
      else
        actual=$(docker run --rm "$image" $run_args 2>&1 || true)
      fi
      ;;
    http)
      # run container in background mapped to a random host port
      host_port=$(shuf -i 20000-60000 -n 1)
      # run_args should contain container port (e.g. 80)
      container_port="${run_args:-80}"
      cid=$(docker run -d -p ${host_port}:${container_port} "$image" )
      sleep 1
      # input contains method and path like: GET /path
      method=$(printf "%s" "$input" | awk '{print $1}')
      path=$(printf "%s" "$input" | awk '{print $2}')
      if [ -z "$path" ]; then path="/"; fi
      actual=$(curl -s -X "$method" "http://localhost:${host_port}${path}" 2>&1 || true)
      docker rm -f "$cid" >/dev/null 2>&1 || true
      ;;
    *)
      actual="UNSUPPORTED_TEST_TYPE:$test_type"
      ;;
  esac

  actual=$(normalize "$actual")
  expected=$(normalize "$expected")

  if compare_output "$expected" "$actual" "$mode"; then
    pass "${student}/${project}: test ($test_type ${run_args}) PASSED"
    return 0
  else
    fail "${student}/${project}: test ($test_type ${run_args}) FAILED"
    return 1
  fi
}

grade_project() {
  local student_dir="$1" project="$2"
  local project_path="$student_dir/$project"
  if [ ! -d "$project_path" ]; then
    info "Skipping ${student_dir}/${project}: directory not found"
    return
  fi
  if [ ! -f "$project_path/Dockerfile" ]; then
    info "Skipping ${student_dir}/${project}: no Dockerfile"
    return
  fi

  local tag="grader_$(basename "$student_dir")_${project}"
  info "Building image ${tag} from ${project_path}"
  if ! docker build -t "$tag" "$project_path"; then
    fail "Build failed for ${student_dir}/${project}"
    return
  fi

  local tests_file="$TEST_DIR/grading_tests/${project}.tests"
  local test
  local total=0 passed=0

  if [ -f "$tests_file" ]; then
    mapfile -t file_tests < <(grep -vE '^\s*$|^\s*#' "$tests_file")
    for test in "${file_tests[@]:-}"; do
      total=$((total+1))
      if run_testcase "$tag" "$test" "$(basename "$student_dir")" "$project"; then
        passed=$((passed+1))
      fi
    done
  else
    local tests_var_name="${project}_tests"
    local -n tests_ref=$tests_var_name
    for test in "${tests_ref[@]:-}"; do
      total=$((total+1))
      if run_testcase "$tag" "$test" "$(basename "$student_dir")" "$project"; then
        passed=$((passed+1))
      fi
    done
  fi

  info "${student_dir}/${project}: $passed/$total tests passed"

  # optional: remove image to save space
  docker rmi "$tag" >/dev/null 2>&1 || true
}

main() {
  info "Starting grading run. Logfile: $LOGFILE"
  for student in */; do
    # skip non-directories
    [ -d "$student" ] || continue
    # skip common files and the script itself
    case "$student" in
      README.md|.git/|.*) continue;;
    esac
    # trim trailing slash
    student_dir="${student%/}"
    for project in "${PROJECTS[@]}"; do
      grade_project "$student_dir" "$project"
    done
  done
  info "Grading run complete"
}

main "$@"
