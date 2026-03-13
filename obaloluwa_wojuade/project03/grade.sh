#!/bin/bash
# Automated grading script for COSC 352 Docker projects
# Usage: ./grade.sh -p [project_num] -s [student_name]

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
WORKSPACE_ROOT="/workspaces/COSC_352_SPRING_2026"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="${SCRIPT_DIR}/grading_logs"
LOG_FILE="${LOG_DIR}/grading_${TIMESTAMP}.log"
TEMP_DIR="/tmp/grading_temp_${TIMESTAMP}"
TIMEOUT_SECONDS=30

# Point deductions
DEDUCT_NON_FUNCTIONAL=30
DEDUCT_MISSING_FEATURES=10
DEDUCT_POOR_READABILITY=10
DEDUCT_POOR_DESIGN=10
DEDUCT_VALIDATION_FAILURE=10
DEDUCT_ERROR_HANDLING=10
DEDUCT_DISALLOWED_TOOLS=30

START_SCORE=100

# Setup logging
init_logging() {
    mkdir -p "${LOG_DIR}"
    mkdir -p "${TEMP_DIR}"
    
    {
        echo "Grading Session - $(date)"
        echo ""
    } | tee "${LOG_FILE}"
}

# Log to screen and file
log_message() {
    local level=$1
    shift
    local message="$@"
    local color=""
    
    case $level in
        "INFO") color="${BLUE}" ;;
        "SUCCESS") color="${GREEN}" ;;
        "WARN") color="${YELLOW}" ;;
        "ERROR") color="${RED}" ;;
        *) color="${NC}" ;;
    esac
    
    echo -e "${color}[${level}]${NC} ${message}" | tee -a "${LOG_FILE}" >&2
}

# Define test cases for each project
define_project_tests() {
    local project=$1
    TESTS=()
    
    case $project in
        01)
            # Test basic hello world
            TESTS+=(
                "test1"
                "Alice"
                "Hello World Alice"
            )
            TESTS+=(
                "test2"
                "Bob"
                "Hello World Bob"
            )
            TESTS+=(
                "test3"
                "John Doe"
                "Hello World John Doe"
            )
            ;;
        02)
            # HTML to CSV project - just check it runs
            TESTS+=(
                "filetest1"
                "FILE_BASED"
                "auto"
            )
            ;;
        *)
            log_message "ERROR" "Unknown project: $project"
            return 1
            ;;
    esac
    
    return 0
}

# Get test case at index
get_test_case() {
    local index=$1
    local test_name="${TESTS[$((index*3))]}"
    local test_input="${TESTS[$((index*3+1))]}"
    local expected="${TESTS[$((index*3+2))]}"
    
    echo "$test_name" "$test_input" "$expected"
}

# Count total tests
get_test_count() {
    echo $((${#TESTS[@]} / 3))
}

# Build docker image for a student
build_docker_image() {
    local student=$1
    local project=$2
    local project_dir="${WORKSPACE_ROOT}/${student}/project${project}"
    local image_name="cosc352_${student}_project${project}"
    
    if [[ ! -f "${project_dir}/Dockerfile" ]]; then
        log_message "WARN" "No Dockerfile found"
        return 1
    fi
    
    log_message "INFO" "Building image..."
    
    if docker build -t "$image_name" "$project_dir" &>> "${LOG_FILE}"; then
        log_message "SUCCESS" "Built: $image_name"
        echo "$image_name"
        return 0
    else
        log_message "ERROR" "Build failed"
        return 1
    fi
}

# Run container with test input
run_container_test() {
    local image_name=$1
    local test_input=$2
    local project=$3
    local student=$4
    local output_file="${TEMP_DIR}/${student}_${project}_output.txt"
    local test_type=$5  # "STDIN" or "ARG" or "FILE_BASED"
    
    # Determine how to pass input based on project type
    case $project in
        01)
            test_type="ARG"
            ;;
        02)
            test_type="FILE_BASED"
            ;;
    esac
    
    case $test_type in
        "ARG")
            # Pass as command-line argument
            if timeout ${TIMEOUT_SECONDS} docker run --rm "$image_name" "$test_input" > "$output_file" 2>&1; then
                cat "$output_file"
                return 0
            else
                return 1
            fi
            ;;
        "STDIN")
            # Pass via stdin
            if echo "$test_input" | timeout ${TIMEOUT_SECONDS} docker run --rm -i "$image_name" > "$output_file" 2>&1; then
                cat "$output_file"
                return 0
            else
                return 1
            fi
            ;;
        "FILE_BASED")
            # File-based project (no input, just runs and produces files)
            if timeout ${TIMEOUT_SECONDS} docker run --rm "$image_name" > "$output_file" 2>&1; then
                cat "$output_file"
                return 0
            else
                return 1
            fi
            ;;
    esac
}

# Compare actual vs expected output
compare_output() {
    local actual=$1
    local expected=$2
    
    # Trim whitespace for comparison
    actual=$(echo "$actual" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    expected=$(echo "$expected" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [[ "$actual" == "$expected" ]]; then
        return 0
    else
        return 1
    fi
}

# Grade a student's project
grade_student_project() {
    local student=$1
    local project=$2
    
    log_message "INFO" "Grading: ${student}/project${project}"
    
    local score=$START_SCORE
    local passed_tests=0
    local failed_tests=0
    local image_name=""
    local deductions=""
    
    # Check if project directory exists
    if [[ ! -d "${WORKSPACE_ROOT}/${student}/project${project}" ]]; then
        log_message "ERROR" "Project directory not found: ${student}/project${project}"
        echo "${student}" "project${project}" "0" "Project directory not found" >> "${LOG_FILE}"
        return
    fi
    
    # Step 1: Build Docker image
    image_name=$(build_docker_image "$student" "$project")
    if [[ -z "$image_name" ]]; then
        score=$((score - DEDUCT_NON_FUNCTIONAL))
        deductions="${deductions}Non-functional (-${DEDUCT_NON_FUNCTIONAL}), "
        log_message "ERROR" "FAILED: Non-functional (build failed)"
        echo "${student}" "project${project}" "${score}" "Build failed" >> "${LOG_FILE}"
        cleanup_docker_image "$image_name"
        return
    fi
    
    # Step 2: Define test cases for this project
    define_project_tests "$project" || {
        score=$((score - DEDUCT_NON_FUNCTIONAL))
        log_message "ERROR" "FAILED: Unable to define test cases"
        cleanup_docker_image "$image_name"
        return
    }
    
    # Step 3: Run test cases
    local test_count=$(get_test_count)
    
    if [[ $test_count -eq 0 ]]; then
        log_message "WARN" "No test cases defined for project${project}"
        cleanup_docker_image "$image_name"
        return
    fi
    
    for ((i=0; i<test_count; i++)); do
        read -r test_name test_input expected_output <<< "$(get_test_case $i)"
        
        log_message "INFO" "Test $test_name: $test_input"
        
        actual_output=$(run_container_test "$image_name" "$test_input" "$project" "$student" "$test_name")
        exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            log_message "ERROR" "$test_name failed (crashed or timed out)"
            ((failed_tests++))
            score=$((score - (DEDUCT_VALIDATION_FAILURE / test_count)))
            continue
        fi
        
        if [[ "$expected_output" == "auto" ]]; then
            log_message "SUCCESS" "$test_name passed"
            ((passed_tests++))
        else
            if compare_output "$actual_output" "$expected_output"; then
                log_message "SUCCESS" "$test_name passed"
                ((passed_tests++))
            else
                log_message "ERROR" "$test_name failed"
                log_message "INFO" "  Expected: $expected_output"
                log_message "INFO" "  Got: $actual_output"
                ((failed_tests++))
                score=$((score - (DEDUCT_VALIDATION_FAILURE / test_count)))
            fi
        fi
    done
    
    check_dockerfile_quality "$student" "$project" score
    
    cleanup_docker_image "$image_name"
    
    # Summary
    local status="PASS"
    if [[ $score -lt 70 ]]; then
        status="FAIL"
    elif [[ $score -lt 85 ]]; then
        status="WARN"
    fi
    
    {
        echo ""
        echo "${student}/project${project}: $status"
        echo "  Score: ${score}/100"
        echo "  Tests: $passed_tests passed, $failed_tests failed"
        echo ""
    } | tee -a "${LOG_FILE}"
}

# Check Dockerfile for comments and basic quality
check_dockerfile_quality() {
    local student=$1
    local project=$2
    local -n score_ref=$3
    local dockerfile="${WORKSPACE_ROOT}/${student}/project${project}/Dockerfile"
    
    if [[ ! -f "$dockerfile" ]]; then
        return
    fi
    
    if ! grep -q "^#" "$dockerfile"; then
        log_message "WARN" "Dockerfile has no comments (-5 pts)"
        score_ref=$((score_ref - (DEDUCT_POOR_READABILITY / 2)))
    fi
    
    if ! grep -q "^FROM" "$dockerfile"; then
        log_message "WARN" "Dockerfile missing FROM (-10 pts)"
        score_ref=$((score_ref - DEDUCT_MISSING_FEATURES))
    fi
}

# Remove docker image after grading
cleanup_docker_image() {
    local image_name=$1
    
    if [[ -n "$image_name" ]] && docker image inspect "$image_name" &> /dev/null; then
        docker rmi -f "$image_name" &>> "${LOG_FILE}"
    fi
}

# Clean temp files
cleanup_temp_files() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Get list of students to grade
get_student_list() {
    local specific_student=$1
    
    if [[ -n "$specific_student" ]]; then
        echo "$specific_student"
    else
        # Get all student directories, excluding special ones
        find "${WORKSPACE_ROOT}" -maxdepth 1 -type d ! -name "COSC_352_SPRING_2026" ! -name ".git" ! -name ".*" ! -path "${WORKSPACE_ROOT}" | xargs -n1 basename | sort
    fi
}

# Print summary
print_summary() {
    local project=$1
    
    {
        echo ""
        echo "Grading Complete - Project ${project}"
        echo "Log: ${LOG_FILE}"
        echo ""
    } | tee -a "${LOG_FILE}"
}

# Help message
show_help() {
    cat << EOF
Grading Script
Usage: ./grade.sh [OPTIONS]

OPTIONS:
    -p, --project PROJECT    Project number to grade (01 or 02) [default: 01]
    -s, --student STUDENT    Grade specific student (grade all if not specified)
    -h, --help              Show this help message

EXAMPLES:
    ./grade.sh                           # Grade project 01 for all students
    ./grade.sh -p 02                     # Grade project 02 for all students
    ./grade.sh -p 01 -s john_doe         # Grade project 01 for john_doe
    ./grade.sh --project 02 --student jane_smith

EOF
}

# Main
PROJECT="01"
SPECIFIC_STUDENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            PROJECT="$2"
            shift 2
            ;;
        -s|--student)
            SPECIFIC_STUDENT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate project number
if [[ ! "$PROJECT" =~ ^0[1-2]$ ]]; then
    log_message "ERROR" "Invalid project number. Must be 01 or 02"
    exit 1
fi

# Update log filename to include student name if grading specific student
if [[ -n "$SPECIFIC_STUDENT" ]]; then
    LOG_FILE="${LOG_DIR}/${SPECIFIC_STUDENT}_grading_${TIMESTAMP}.log"
fi

# Initialize
init_logging
log_message "INFO" "Project: $PROJECT"
log_message "INFO" "Specific Student: ${SPECIFIC_STUDENT:-'All students'}"
log_message "INFO" "Log file: ${LOG_FILE}"
echo ""

# Get student list
STUDENTS=$(get_student_list "$SPECIFIC_STUDENT")
STUDENT_COUNT=$(echo "$STUDENTS" | wc -l)

log_message "INFO" "Found $STUDENT_COUNT student(s) to grade"
echo ""

# Grade each student
TOTAL_PROCESSED=0
TOTAL_PASSED=0
TOTAL_FAILED=0

for student in $STUDENTS; do
    # Skip if not a valid student directory
    if [[ ! -d "${WORKSPACE_ROOT}/${student}/project${PROJECT}" ]]; then
        continue
    fi
    
    grade_student_project "$student" "$PROJECT"
    ((TOTAL_PROCESSED++))
done

# Final summary
{
    echo ""
    echo "Done! Graded $TOTAL_PROCESSED students for Project ${PROJECT}"
    echo "Results saved to: ${LOG_FILE}"
} | tee -a "${LOG_FILE}"

cleanup_temp_files

log_message "SUCCESS" "Grading complete"

exit 0
