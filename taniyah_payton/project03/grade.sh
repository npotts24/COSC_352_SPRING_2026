#!/bin/bash
# =============================================================================
# grade.sh - Automated Docker Container Grading Script
# =============================================================================
# Description:
#   Automates grading of student Docker container projects by:
#   - Iterating through all student directories
#   - Building and running each student's Docker container
#   - Sending test inputs and capturing outputs
#   - Comparing outputs against expected results
#   - Logging results to terminal and file simultaneously
#
# Usage:
#   ./grade.sh [PROJECT] [REPO_DIR] [LOG_FILE]
#
# Arguments:
#   PROJECT   - Project to grade: "project01" or "project02" (default: project01)
#   REPO_DIR  - Path to the course repository (default: current directory)
#   LOG_FILE  - Path to log file (default: grading_results.log)
#
# Examples:
#   ./grade.sh project01
#   ./grade.sh project02 /path/to/COSC_352_SPRING_2026 results.log
#
# Requirements:
#   - Docker must be installed and running
#   - Student directories must contain a Dockerfile
#
# Author: Taniyah Payton
# Course: COSC 352 Spring 2026
# =============================================================================

# =============================================================================
# CONFIGURATION - Modify this section for different projects
# =============================================================================

# Project to grade (can be overridden by command line argument)
PROJECT="${1:-project01}"

# Root directory of the course repository
REPO_DIR="${2:-$(pwd)}"

# Log file for grading results
LOG_FILE="${3:-grading_results_${PROJECT}.log}"

# Docker image name prefix (will be appended with student name)
IMAGE_PREFIX="cosc352"

# Timeout in seconds for Docker build and run
BUILD_TIMEOUT=120
RUN_TIMEOUT=30

# Maximum points per student
MAX_POINTS=100

# =============================================================================
# TEST CASES - Modify this section to define test inputs/outputs per project
# =============================================================================
# Format:
#   TEST_INPUTS  - array of inputs to send to the container
#   TEST_OUTPUTS - array of expected outputs (must match TEST_INPUTS order)
#   TEST_METHOD  - how to send input: "stdin", "http", or "args"
#   HTTP_PORT    - port to use if TEST_METHOD is "http"

configure_tests() {
    if [[ "$PROJECT" == "project01" ]]; then
        # -----------------------------------------------
        # Project 01: Hello World Python container tests
        # -----------------------------------------------
        TEST_METHOD="stdin"
        HTTP_PORT=""

        # Test inputs (what we send to the container)
        TEST_INPUTS=(
            "World"
            "COSC352"
            "Docker"
        )

        # Expected outputs (what the container should print)
        TEST_OUTPUTS=(
            "Hello, World!"
            "Hello, COSC352!"
            "Hello, Docker!"
        )

    elif [[ "$PROJECT" == "project02" ]]; then
        # -----------------------------------------------
        # Project 02: HTML Table Parser container tests
        # -----------------------------------------------
        TEST_METHOD="args"
        HTTP_PORT=""

        # Test inputs (arguments passed to the container)
        TEST_INPUTS=(
            "test_example.html"
            "--help"
        )

        # Expected outputs (strings that should appear in container output)
        TEST_OUTPUTS=(
            "output.csv"
            "Usage:"
        )

    else
        # -----------------------------------------------
        # Default / Future projects - add new ones here
        # -----------------------------------------------
        log "ERROR: Unknown project '$PROJECT'. Add test cases in configure_tests()."
        exit 1
    fi
}

# =============================================================================
# LOGGING - Outputs to both terminal and log file simultaneously
# =============================================================================

# Initialize log file
init_log() {
    echo "==============================================================================" > "$LOG_FILE"
    echo "  COSC 352 Automated Grading - $PROJECT" >> "$LOG_FILE"
    echo "  Date: $(date)" >> "$LOG_FILE"
    echo "  Repository: $REPO_DIR" >> "$LOG_FILE"
    echo "==============================================================================" >> "$LOG_FILE"
}

# Log a message to both terminal and file
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Log a section divider
log_divider() {
    log "------------------------------------------------------------------------------"
}

# Log with color to terminal, plain to file
log_pass() {
    echo -e "\e[32m$1\e[0m"       # Green to terminal
    echo "$1" >> "$LOG_FILE"       # Plain to file
}

log_fail() {
    echo -e "\e[31m$1\e[0m"       # Red to terminal
    echo "$1" >> "$LOG_FILE"       # Plain to file
}

log_warn() {
    echo -e "\e[33m$1\e[0m"       # Yellow to terminal
    echo "$1" >> "$LOG_FILE"       # Plain to file
}

log_info() {
    echo -e "\e[36m$1\e[0m"       # Cyan to terminal
    echo "$1" >> "$LOG_FILE"       # Plain to file
}

# =============================================================================
# DOCKER HELPERS
# =============================================================================

# Build a Docker image from a student's project directory
# Args: $1 = image_name, $2 = dockerfile_dir
build_image() {
    local image_name="$1"
    local dockerfile_dir="$2"

    log "  [BUILD] Building image: $image_name"

    # Run docker build with timeout, capture output
    build_output=$(timeout "$BUILD_TIMEOUT" docker build -t "$image_name" "$dockerfile_dir" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_pass "  [BUILD] ✓ Build successful"
        return 0
    elif [[ $exit_code -eq 124 ]]; then
        log_fail "  [BUILD] ✗ Build timed out after ${BUILD_TIMEOUT}s"
        return 1
    else
        log_fail "  [BUILD] ✗ Build failed (exit code: $exit_code)"
        log "  [BUILD] Output: $(echo "$build_output" | tail -5)"
        return 1
    fi
}

# Run a container with stdin input and capture output
# Args: $1 = image_name, $2 = input
run_with_stdin() {
    local image_name="$1"
    local input="$2"

    echo "$input" | timeout "$RUN_TIMEOUT" docker run --rm -i "$image_name" 2>&1
    return $?
}

# Run a container with command arguments and capture output
# Args: $1 = image_name, $2 = args
run_with_args() {
    local image_name="$1"
    local args="$2"

    timeout "$RUN_TIMEOUT" docker run --rm "$image_name" $args 2>&1
    return $?
}

# Run a container as HTTP server and test with curl
# Args: $1 = image_name, $2 = http_input (URL path), $3 = port
run_with_http() {
    local image_name="$1"
    local http_input="$2"
    local port="$3"

    # Start container in background
    local container_id
    container_id=$(docker run -d -p "${port}:${port}" "$image_name" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to start container"
        return 1
    fi

    # Wait for container to be ready
    local retries=10
    while [[ $retries -gt 0 ]]; do
        if curl -s "http://localhost:${port}" > /dev/null 2>&1; then
            break
        fi
        sleep 1
        ((retries--))
    done

    # Send request and capture output
    local output
    output=$(timeout "$RUN_TIMEOUT" curl -s "http://localhost:${port}${http_input}" 2>&1)

    # Stop and remove container
    docker stop "$container_id" > /dev/null 2>&1
    docker rm "$container_id" > /dev/null 2>&1

    echo "$output"
    return 0
}

# Clean up Docker image after grading
# Args: $1 = image_name
cleanup_image() {
    local image_name="$1"
    docker rmi -f "$image_name" > /dev/null 2>&1
    log "  [CLEAN] Removed image: $image_name"
}

# =============================================================================
# TEST RUNNER
# =============================================================================

# Run all test cases against a student's container
# Args: $1 = image_name
# Returns: number of tests passed
run_tests() {
    local image_name="$1"
    local passed=0
    local total=${#TEST_INPUTS[@]}

    for i in "${!TEST_INPUTS[@]}"; do
        local input="${TEST_INPUTS[$i]}"
        local expected="${TEST_OUTPUTS[$i]}"
        local test_num=$((i + 1))

        log "  [TEST $test_num/$total] Input: '$input'"
        log "  [TEST $test_num/$total] Expected: '$expected'"

        # Run container based on test method
        local actual_output
        case "$TEST_METHOD" in
            "stdin")
                actual_output=$(run_with_stdin "$image_name" "$input")
                ;;
            "args")
                actual_output=$(run_with_args "$image_name" "$input")
                ;;
            "http")
                actual_output=$(run_with_http "$image_name" "$input" "$HTTP_PORT")
                ;;
            *)
                log_warn "  [TEST $test_num/$total] Unknown test method: $TEST_METHOD"
                continue
                ;;
        esac

        local exit_code=$?

        # Check for timeout
        if [[ $exit_code -eq 124 ]]; then
            log_fail "  [TEST $test_num/$total] ✗ FAIL - Container timed out after ${RUN_TIMEOUT}s"
            continue
        fi

        log "  [TEST $test_num/$total] Actual:   '$(echo "$actual_output" | head -1)'"

        # Compare actual output to expected (check if expected string is in output)
        if echo "$actual_output" | grep -qF "$expected"; then
            log_pass "  [TEST $test_num/$total] ✓ PASS"
            ((passed++))
        else
            log_fail "  [TEST $test_num/$total] ✗ FAIL"
        fi
    done

    echo "$passed"
}

# =============================================================================
# STUDENT GRADER
# =============================================================================

# Grade a single student
# Args: $1 = student_name, $2 = project_dir
grade_student() {
    local student_name="$1"
    local project_dir="$2"
    local image_name="${IMAGE_PREFIX}_${student_name}_${PROJECT}"
    local total_tests=${#TEST_INPUTS[@]}
    local score=0

    log ""
    log_divider
    log_info "  STUDENT: $student_name"
    log "  PROJECT: $PROJECT"
    log "  DIRECTORY: $project_dir"
    log_divider

    # Check if Dockerfile exists
    if [[ ! -f "$project_dir/Dockerfile" ]]; then
        log_fail "  [ERROR] No Dockerfile found in $project_dir"
        log "  SCORE: 0 / $MAX_POINTS (No Dockerfile)"
        echo "0"
        return
    fi

    # Build the Docker image
    if ! build_image "$image_name" "$project_dir"; then
        log_fail "  [ERROR] Build failed - skipping tests"
        log "  SCORE: 0 / $MAX_POINTS (Build failed)"
        echo "0"
        return
    fi

    # Run all test cases
    local passed
    passed=$(run_tests "$image_name")

    # Calculate score based on test results
    if [[ $total_tests -gt 0 ]]; then
        score=$(( (passed * MAX_POINTS) / total_tests ))
    else
        score=$MAX_POINTS
    fi

    # Clean up Docker image
    cleanup_image "$image_name"

    # Report results
    log_divider
    if [[ $passed -eq $total_tests ]]; then
        log_pass "  RESULT: $passed/$total_tests tests passed"
        log_pass "  SCORE:  $score / $MAX_POINTS ✓"
    else
        log_warn "  RESULT: $passed/$total_tests tests passed"
        log_warn "  SCORE:  $score / $MAX_POINTS"
    fi

    echo "$score"
}

# =============================================================================
# SUMMARY REPORT
# =============================================================================

# Print final summary of all grading results
# Args: arrays of student names and scores
print_summary() {
    local -n _names=$1
    local -n _scores=$2
    local total_students=${#_names[@]}
    local total_passed=0
    local total_failed=0
    local grand_total=0

    log ""
    log "=============================================================================="
    log_info "  FINAL GRADING SUMMARY - $PROJECT"
    log "=============================================================================="
    log "  $(printf '%-30s %s' 'STUDENT' 'SCORE')"
    log_divider

    for i in "${!_names[@]}"; do
        local name="${_names[$i]}"
        local score="${_scores[$i]}"
        grand_total=$((grand_total + score))

        if [[ $score -ge $MAX_POINTS ]]; then
            log_pass "  $(printf '%-30s %d / %d ✓' "$name" "$score" "$MAX_POINTS")"
            ((total_passed++))
        elif [[ $score -gt 0 ]]; then
            log_warn "  $(printf '%-30s %d / %d ~' "$name" "$score" "$MAX_POINTS")"
            ((total_failed++))
        else
            log_fail "  $(printf '%-30s %d / %d ✗' "$name" "$score" "$MAX_POINTS")"
            ((total_failed++))
        fi
    done

    local avg_score=0
    if [[ $total_students -gt 0 ]]; then
        avg_score=$((grand_total / total_students))
    fi

    log_divider
    log "  Total Students : $total_students"
    log "  Full Score     : $total_passed"
    log "  Partial/Zero   : $total_failed"
    log "  Average Score  : $avg_score / $MAX_POINTS"
    log "=============================================================================="
    log "  Log saved to: $LOG_FILE"
    log "=============================================================================="
}

# =============================================================================
# MAIN - Entry point
# =============================================================================

main() {
    # Initialize log file
    init_log

    log ""
    log "=============================================================================="
    log_info "  COSC 352 - Automated Grading System"
    log "  Project  : $PROJECT"
    log "  Repo     : $REPO_DIR"
    log "  Log File : $LOG_FILE"
    log "  Date     : $(date)"
    log "=============================================================================="

    # Load test cases for the selected project
    configure_tests

    log "  Test Cases  : ${#TEST_INPUTS[@]}"
    log "  Test Method : $TEST_METHOD"
    log "  Max Points  : $MAX_POINTS"

    # Check Docker is available and running
    if ! docker info > /dev/null 2>&1; then
        log_fail "ERROR: Docker is not running or not installed!"
        log_fail "Please start Docker and try again."
        exit 1
    fi

    log_pass "  Docker: ✓ Running"

    # Arrays to track all student results
    student_names=()
    student_scores=()

    # Iterate through all student directories in the repo
    for student_dir in "$REPO_DIR"/*/; do
        # Skip non-directories
        [[ -d "$student_dir" ]] || continue

        # Get student name from directory name
        student_name=$(basename "$student_dir")

        # Skip the professor's directory and hidden folders
        if [[ "$student_name" == "professor_"* ]] || [[ "$student_name" == .* ]]; then
            continue
        fi

        # Build path to student's project directory
        project_path="${student_dir}${PROJECT}"

        # Skip if student doesn't have this project directory
        if [[ ! -d "$project_path" ]]; then
            log ""
            log_warn "  SKIP: $student_name (no $PROJECT directory found)"
            student_names+=("$student_name")
            student_scores+=("0")
            continue
        fi

        # Grade the student
        score=$(grade_student "$student_name" "$project_path")
        student_names+=("$student_name")
        student_scores+=("$score")
    done

    # Print final summary
    print_summary student_names student_scores

    log ""
    log "Grading complete!"
}

# Run main function
main
