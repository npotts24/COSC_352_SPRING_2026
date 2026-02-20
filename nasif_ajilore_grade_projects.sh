#!/bin/bash

################################################################################
# Automated Docker Container Grading System
# Grades student projects by building Docker containers and running test cases
################################################################################

# Configuration
WORKSPACE_ROOT="/workspaces/COSC_352_SPRING_2026"
PROJECTS=("01" "02")
RESULTS_DIR="${WORKSPACE_ROOT}/nasif_ajilore/project03/results"
TESTS_DIR="${WORKSPACE_ROOT}/nasif_ajilore/project03/tests"
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${RESULTS_DIR}/grading_log_${LOG_TIMESTAMP}.txt"
TIMEOUT=10  # Timeout per test in seconds
TEMP_DIR=$(mktemp -d)

# Ensure results and tests directories exist
mkdir -p "${RESULTS_DIR}" "${TESTS_DIR}"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
declare -A STUDENT_ATTEMPTED
declare -A STUDENT_PASSED
declare -A PROJECT_TOTAL_TESTS
declare -A PROJECT_PASSED_TESTS

################################################################################
# Utility Functions
################################################################################

# Log message to both terminal and file
log_output() {
    local message="$1"
    echo -e "${message}" | tee -a "${LOG_FILE}"
}

# Log to file only (for verbose output)
log_file_only() {
    local message="$1"
    echo -e "${message}" >> "${LOG_FILE}"
}

# Load test cases from a file
# Format: input|expected_output
load_tests() {
    local project=$1
    local test_file="${TESTS_DIR}/project${project}_tests.txt"
    local -n test_array=$2
    
    if [[ ! -f "${test_file}" ]]; then
        return 1
    fi
    
    while IFS='|' read -r input expected; do
        # Skip empty lines and comments
        [[ -z "${input}" || "${input}" =~ ^# ]] && continue
        test_array+=("${input}|${expected}")
    done < "${test_file}"
    
    return 0
}

# Build Docker image from student project
build_image() {
    local student=$1
    local project=$2
    local project_path="${WORKSPACE_ROOT}/${student}/project${project}"
    local image_name="student_${student}_project${project}:latest"
    
    if [[ ! -d "${project_path}" ]]; then
        return 1
    fi
    
    if [[ ! -f "${project_path}/Dockerfile" ]]; then
        return 2
    fi
    
    # Build the image, suppress output to log file, show only errors
    if ! docker build -t "${image_name}" "${project_path}" &>/dev/null; then
        log_file_only "  [BUILD FAILED] Docker build error for ${student}/project${project}"
        return 3
    fi
    
    echo "${image_name}"
    return 0
}

# Run a test case on a Docker container
run_test() {
    local image_name=$1
    local test_input=$2
    local -n output_var=$3
    local project=$4  # Project number (01 or 02)
    
    # Run container with test input as command argument, capture output
    local container_output
    local exit_code
    
    if [[ "${project}" == "02" ]]; then
        # For Project 02, run with volume mount to access created files
        container_output=$(timeout ${TIMEOUT} docker run --rm -v /tmp/p02_test:/tmp/p02_test "${image_name}" "${test_input}" 2>&1)
    else
        # For Project 01 and others, run normally
        container_output=$(timeout ${TIMEOUT} docker run --rm "${image_name}" "${test_input}" 2>&1)
    fi
    
    exit_code=$?
    
    if [[ ${exit_code} -eq 124 ]]; then
        output_var="[TIMEOUT EXCEEDED]"
        return 1
    elif [[ ${exit_code} -ne 0 ]]; then
        output_var="${container_output}"
        return 1
    fi
    
    output_var="${container_output}"
    return 0
}

# Compare actual output with expected output
# Ignores all whitespace (spaces, tabs, newlines) and ellipsis/dots
compare_outputs() {
    local actual=$1
    local expected=$2
    
    # Remove all whitespace and ellipsis for comparison
    local actual_normalized=$(echo "${actual}" | tr -d '[:space:].' | tr -d '\.')
    local expected_normalized=$(echo "${expected}" | tr -d '[:space:].' | tr -d '\.')
    
    if [[ "${actual_normalized}" == "${expected_normalized}" ]]; then
        return 0  # Match
    else
        return 1  # No match
    fi
}

# Clean up Docker image
cleanup_image() {
    local image_name=$1
    docker rmi -f "${image_name}" &>/dev/null
}

# Clean up all test containers and images
cleanup_all() {
    log_output "\n${BLUE}=== Cleanup ===${NC}"
    log_output "Removing test containers and images..."
    
    # Remove all containers with student_ prefix
    docker ps -a --filter "ancestor=student_*" -q 2>/dev/null | xargs -r docker rm -f &>/dev/null
    
    # Remove all images with student_ prefix
    docker images | grep "student_" | awk '{print $3}' | xargs -r docker rmi -f &>/dev/null
    
    # Clean up temp directory
    rm -rf "${TEMP_DIR}"
    
    log_output "Cleanup complete."
}

# Generate final summary report
generate_summary() {
    log_output "\n${BLUE}======================================${NC}"
    log_output "${BLUE}        GRADING SUMMARY REPORT${NC}"
    log_output "${BLUE}======================================${NC}\n"
    
    # Track overall pass/fail status
    local total_attempts=0
    local total_passed=0
    local has_failures=0
    
    for project in "${PROJECTS[@]}"; do
        local total=${PROJECT_TOTAL_TESTS["p${project}"]:-0}
        local passed=${PROJECT_PASSED_TESTS["p${project}"]:-0}
        
        if [[ ${total} -eq 0 ]]; then
            log_output "${YELLOW}Project ${project}: No tests run${NC}"
        else
            total_attempts=$((total_attempts + total))
            total_passed=$((total_passed + passed))
            
            local percent=$((passed * 100 / total))
            if [[ ${passed} -eq ${total} ]]; then
                log_output "${GREEN}Project ${project}: ${passed}/${total} tests passed (${percent}%)${NC}"
            else
                log_output "${RED}Project ${project}: ${passed}/${total} tests passed (${percent}%)${NC}"
                has_failures=1
            fi
        fi
    done
    
    log_output "\n${BLUE}Total students with submissions:${NC}"
    local total_students=0
    for project in "${PROJECTS[@]}"; do
        local attempted=${STUDENT_ATTEMPTED["p${project}"]:-0}
        if [[ ${attempted} -gt 0 ]]; then
            log_output "  Project ${project}: ${attempted} students"
            total_students=$((total_students + attempted))
        fi
    done
    
    log_output "\n${BLUE}Log file saved to: ${LOG_FILE}${NC}\n"
    
    # Determine pass/fail status for naming
    if [[ ${total_attempts} -gt 0 ]]; then
        if [[ ${total_passed} -eq ${total_attempts} ]]; then
            echo "ALL_TESTS_PASSED"
        elif [[ ${has_failures} -eq 1 ]]; then
            # Check if some passed and some failed (mixed) or all failed
            if [[ ${total_passed} -eq 0 ]]; then
                echo "ALL_TESTS_FAILED"
            else
                echo "MIXED_RESULTS"
            fi
        fi
    fi
}

# Rename log file based on test results
rename_log_file() {
    local status="$1"
    local old_log="${LOG_FILE}"
    local new_log=""
    
    if [[ -z "${status}" ]]; then
        return
    fi
    
    case "${status}" in
        ALL_TESTS_PASSED)
            new_log="${RESULTS_DIR}/grading_log_ALL_TESTS_PASSED.txt"
            ;;
        ALL_TESTS_FAILED)
            new_log="${RESULTS_DIR}/grading_log_ALL_TESTS_FAILED.txt"
            ;;
        MIXED_RESULTS)
            new_log="${RESULTS_DIR}/grading_log_MIXED_RESULTS_${LOG_TIMESTAMP}.txt"
            ;;
        *)
            return
            ;;
    esac
    
    if [[ -f "${old_log}" && "${old_log}" != "${new_log}" ]]; then
        mv "${old_log}" "${new_log}"
        echo "✓ Log renamed to: $(basename ${new_log})"
    fi
}

################################################################################
# Main Grading Logic
################################################################################

main() {
    log_output "${BLUE}======================================${NC}"
    log_output "${BLUE}  AUTOMATED GRADING SYSTEM STARTING${NC}"
    log_output "${BLUE}======================================${NC}\n"
    log_output "Workspace: ${WORKSPACE_ROOT}"
    log_output "Log file: ${LOG_FILE}"
    log_output "Timestamp: $(date)"
    log_output ""
    
    # Initialize counters
    for project in "${PROJECTS[@]}"; do
        STUDENT_ATTEMPTED["p${project}"]=0
        STUDENT_PASSED["p${project}"]=0
        PROJECT_TOTAL_TESTS["p${project}"]=0
        PROJECT_PASSED_TESTS["p${project}"]=0
    done
    
    # Load all test cases
    declare -a tests_p01
    declare -a tests_p02
    
    if ! load_tests "01" tests_p01; then
        log_output "${YELLOW}Warning: Project 01 test file not found${NC}"
    else
        log_output "${GREEN}✓ Loaded ${#tests_p01[@]} test cases for Project 01${NC}"
    fi
    
    if ! load_tests "02" tests_p02; then
        log_output "${YELLOW}Note: Project 02 test file not configured${NC}"
    else
        log_output "${GREEN}✓ Loaded ${#tests_p02[@]} test cases for Project 02${NC}"
    fi
    log_output ""
    
    # Iterate through all student directories
    for student_dir in "${WORKSPACE_ROOT}"/*; do
        [[ ! -d "${student_dir}" ]] && continue
        
        student=$(basename "${student_dir}")
        
        # Skip non-student directories
        [[ "${student}" == "professor_jon_white" ]] && continue
        [[ "${student}" == ".git" ]] && continue
        [[ "${student}" =~ ^grading || "${student}" =~ ^project ]] && continue
        
        log_output "${YELLOW}─────────────────────────────────────${NC}"
        log_output "${BLUE}Student: ${student}${NC}"
        
        # Grade each project for this student
        for project in "${PROJECTS[@]}"; do
            # Prepare test array based on project
            local -n test_array="tests_p${project}"
            
            # Skip if no tests are defined
            if [[ ${#test_array[@]} -eq 0 ]]; then
                log_file_only "  Project ${project}: No tests defined, skipping"
                continue
            fi
            
            log_output "  ${BLUE}Project ${project}:${NC}"
            
            # Try to build image
            image_result=$(build_image "${student}" "${project}" 2>&1)
            build_status=$?
            
            if [[ ${build_status} -eq 1 ]]; then
                log_output "    ${YELLOW}Project directory not found${NC}"
                log_file_only "    Project directory: ${WORKSPACE_ROOT}/${student}/project${project}"
                continue
            elif [[ ${build_status} -eq 2 ]]; then
                log_output "    ${YELLOW}Dockerfile not found (not attempted)${NC}"
                log_file_only "    No Dockerfile in project${project}"
                continue
            elif [[ ${build_status} -eq 3 ]]; then
                log_output "    ${RED}✗ Build failed${NC}"
                log_file_only "    ${image_result}"
                continue
            fi
            
            image_name="${image_result}"
            log_output "    ${GREEN}✓ Build successful${NC}"
            log_file_only "    Image: ${image_name}"
            
            # Mark as attempted
            STUDENT_ATTEMPTED["p${project}"]=$((${STUDENT_ATTEMPTED["p${project}"]} + 1))
            
            # Run each test case
            local test_num=1
            local project_passed=0
            
            for test_case in "${test_array[@]}"; do
                # Parse test case - format differs by project
                local actual_output
                local test_pass=0
                
                if [[ "${project}" == "02" ]]; then
                    # Project 02: test_url|expected_header|min_rows|expected_columns
                    IFS='|' read -r test_input expected_header min_rows expected_cols <<< "${test_case}"
                    run_test "${image_name}" "${test_input}" actual_output "${project}"
                    
                    # For Project 02, check if CSV files were created and contain expected data
                    # Look for success message and verify output structure
                    if echo "${actual_output}" | grep -q "Successfully saved" && \
                       echo "${actual_output}" | grep -q "Summary.*tables exported successfully"; then
                        # Check if the expected header appears in the output
                        if echo "${actual_output}" | grep -q "Language.*Imperative" || \
                           echo "${actual_output}" | grep -q "Dimensions.*rows.*columns"; then
                            test_pass=1
                        fi
                    fi
                    
                    if [[ ${test_pass} -eq 1 ]]; then
                        log_output "    ${GREEN}  Test ${test_num}: ✓ PASS${NC}"
                        log_file_only "    Test ${test_num}: PASS"
                        log_file_only "      Input: ${test_input}"
                        log_file_only "      Expected: Tables with header containing '${expected_header}' and ~${min_rows} rows"
                        log_file_only "      Actual: CSV files successfully created"
                        PROJECT_PASSED_TESTS["p${project}"]=$((${PROJECT_PASSED_TESTS["p${project}"]} + 1))
                        project_passed=$((project_passed + 1))
                    else
                        log_output "    ${RED}  Test ${test_num}: ✗ FAIL${NC}"
                        log_file_only "    Test ${test_num}: FAIL"
                        log_file_only "      Input: ${test_input}"
                        log_file_only "      Expected: CSV files with programming language data"
                        log_file_only "      Actual output: ${actual_output}"
                    fi
                else
                    # Project 01 and others: simple input|expected_output format
                    IFS='|' read -r test_input expected_output <<< "${test_case}"
                    run_test "${image_name}" "${test_input}" actual_output "${project}"
                    
                    if compare_outputs "${actual_output}" "${expected_output}"; then
                        log_output "    ${GREEN}  Test ${test_num}: ✓ PASS${NC}"
                        log_file_only "    Test ${test_num}: PASS"
                        log_file_only "      Input: ${test_input}"
                        log_file_only "      Expected: ${expected_output}"
                        log_file_only "      Actual: ${actual_output}"
                        PROJECT_PASSED_TESTS["p${project}"]=$((${PROJECT_PASSED_TESTS["p${project}"]} + 1))
                        project_passed=$((project_passed + 1))
                    else
                        log_output "    ${RED}  Test ${test_num}: ✗ FAIL${NC}"
                        log_file_only "    Test ${test_num}: FAIL"
                        log_file_only "      Input: ${test_input}"
                        log_file_only "      Expected: ${expected_output}"
                        log_file_only "      Actual: ${actual_output}"
                    fi
                fi
                
                PROJECT_TOTAL_TESTS["p${project}"]=$((${PROJECT_TOTAL_TESTS["p${project}"]} + 1))
                test_num=$((test_num + 1))
            done
            
            # Summary for this project
            local total_tests=${#test_array[@]}
            log_file_only "    Project ${project} Summary: ${project_passed}/${total_tests} tests passed"
            
            # Update student passed count if all tests passed
            if [[ ${project_passed} -eq ${total_tests} ]]; then
                STUDENT_PASSED["p${project}"]=$((${STUDENT_PASSED["p${project}"]} + 1))
            fi
            
            # Clean up image
            cleanup_image "${image_name}"
        done
    done
    
    # Generate summary and cleanup
    local test_status=$(generate_summary)
    rename_log_file "${test_status}"
    cleanup_all
    
    log_output "${GREEN}Grading complete!${NC}\n"
}

# Set up signal handling for cleanup
trap cleanup_all EXIT

# Run main function
main "$@"
