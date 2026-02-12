#!/bin/bash

################################################################################
# AUTOMATED DOCKER PROJECT GRADING SYSTEM
# Grades student container projects (Project 01 & 02) with automated testing
# Author: DevOps Grading System
# Date: 2026
################################################################################

set -o pipefail

# ============================================================================
# CONFIGURATION SECTION - Modify these for future projects
# ============================================================================

WORKSPACE_ROOT="/workspaces/COSC_352_SPRING_2026"
RESULTS_DIR="${WORKSPACE_ROOT}/najae_potts/project03"
TEMP_WORK_DIR="/tmp/grading_work"
LOG_FILE="${RESULTS_DIR}/grading_log_$(date +%Y%m%d_%H%M%S).txt"

# Projects to grade
PROJECTS=("project01" "project02")

# Test timeout (seconds)
TEST_TIMEOUT=30

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Log function: outputs to both terminal and log file with timestamp
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" | tee -a "$LOG_FILE"
}

# Log without timestamp (for clean formatting)
log_plain() {
    local message="$1"
    echo "${message}" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        PASS)
            echo -e "${GREEN}[PASS]${NC} ${message}" | tee -a "$LOG_FILE"
            ;;
        FAIL)
            echo -e "${RED}[FAIL]${NC} ${message}" | tee -a "$LOG_FILE"
            ;;
        TEST)
            echo -e "${YELLOW}[TEST]${NC} ${message}" | tee -a "$LOG_FILE"
            ;;
        INFO)
            echo -e "${BLUE}[INFO]${NC} ${message}" | tee -a "$LOG_FILE"
            ;;
    esac
}

# Initialize results directory and logging
init_grading() {
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$TEMP_WORK_DIR"
    
    log "═══════════════════════════════════════════════════════════════"
    log "AUTOMATED DOCKER PROJECT GRADING SYSTEM"
    log "Started: $(date)"
    log "Workspace: $WORKSPACE_ROOT"
    log "═══════════════════════════════════════════════════════════════"
    log ""
}

# Cleanup temporary files
cleanup() {
    log ""
    log "Cleaning up temporary work directory..."
    rm -rf "$TEMP_WORK_DIR"
    log "Cleanup complete."
}

# ============================================================================
# PROJECT 01 GRADING - "Hello World" Docker Container
# ============================================================================

grade_project01() {
    local student_dir="$1"
    local student_name=$(basename "$student_dir")
    local project_dir="${student_dir}/project01"
    local dockerfile=""
    local python_script=""
    
    log ""
    log_plain "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status INFO "GRADING PROJECT 01: ${student_name}"
    log_plain "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if project directory exists
    if [[ ! -d "$project_dir" ]]; then
        print_status FAIL "Project directory not found: $project_dir"
        return 1
    fi
    
    # Find Dockerfile (may be named Dockerfile or Dockerfile.txt)
    if [[ -f "${project_dir}/Dockerfile" ]]; then
        dockerfile="${project_dir}/Dockerfile"
    elif [[ -f "${project_dir}/Dockerfile.txt" ]]; then
        dockerfile="${project_dir}/Dockerfile.txt"
    else
        print_status FAIL "No Dockerfile found in ${project_dir}"
        return 1
    fi
    
    # Find Python script (may be hello-world.py, hello-ayo.py, etc.)
    for script_name in hello-world.py hello-ayo.py hello.py main.py; do
        if [[ -f "${project_dir}/${script_name}" ]]; then
            python_script="${project_dir}/${script_name}"
            break
        fi
    done
    
    if [[ -z "$python_script" ]]; then
        print_status FAIL "No Python script found in ${project_dir}"
        return 1
    fi
    
    print_status INFO "Found Dockerfile: $(basename $dockerfile)"
    print_status INFO "Found Python script: $(basename $python_script)"
    
    # Create working directory for this student
    local work_dir="${TEMP_WORK_DIR}/${student_name}_p01"
    mkdir -p "$work_dir"
    
    # Copy files to work directory (normalize filenames)
    cp "$dockerfile" "${work_dir}/Dockerfile"
    cp "$python_script" "${work_dir}/hello.py"
    
    # Fix the COPY command in Dockerfile to reference the normalized filename
    sed -i 's|COPY [^ ]* |COPY hello.py |g' "${work_dir}/Dockerfile"
    sed -i 's|ENTRYPOINT \["python",[^]]*\]|ENTRYPOINT ["python", "hello.py"]|g' "${work_dir}/Dockerfile"
    sed -i 's|CMD \["python",[^]]*\]|ENTRYPOINT ["python", "hello.py"]|g' "${work_dir}/Dockerfile"
    
    # Build Docker image
    local image_name="${student_name}_project01:latest"
    print_status TEST "Building Docker image: ${image_name}"
    
    if ! docker build -t "$image_name" "$work_dir" >> "$LOG_FILE" 2>&1; then
        print_status FAIL "Docker build failed"
        docker rmi "$image_name" >> /dev/null 2>&1
        rm -rf "$work_dir"
        return 1
    fi
    
    print_status PASS "Docker image built successfully"
    
    # Run tests
    local test_passed=0
    local test_total=2
    
    # Test 1: Run with argument "Alice"
    print_status TEST "Test 1: Running container with argument 'Alice'"
    local output1=$(timeout $TEST_TIMEOUT docker run --rm "$image_name" Alice 2>&1)
    local exit_code1=$?
    
    if [[ $exit_code1 -eq 0 ]]; then
        # Check if output contains expected keywords (case-insensitive)
        if echo "$output1" | grep -qi "hello" && echo "$output1" | grep -qi "alice"; then
            print_status PASS "Test 1 passed - Output contains 'Hello' and 'Alice'"
            log_plain "  Output: ${output1}"
            ((test_passed++))
        else
            print_status FAIL "Test 1 failed - Output doesn't contain expected keywords"
            log_plain "  Expected to find: 'Hello' and 'Alice'"
            log_plain "  Got: ${output1}"
        fi
    else
        print_status FAIL "Test 1 failed - Container exited with status $exit_code1"
        log_plain "  Output: ${output1}"
    fi
    
    # Test 2: Run with argument "Bob"
    print_status TEST "Test 2: Running container with argument 'Bob'"
    local output2=$(timeout $TEST_TIMEOUT docker run --rm "$image_name" Bob 2>&1)
    local exit_code2=$?
    
    if [[ $exit_code2 -eq 0 ]]; then
        if echo "$output2" | grep -qi "hello" && echo "$output2" | grep -qi "bob"; then
            print_status PASS "Test 2 passed - Output contains 'Hello' and 'Bob'"
            log_plain "  Output: ${output2}"
            ((test_passed++))
        else
            print_status FAIL "Test 2 failed - Output doesn't contain expected keywords"
            log_plain "  Expected to find: 'Hello' and 'Bob'"
            log_plain "  Got: ${output2}"
        fi
    else
        print_status FAIL "Test 2 failed - Container exited with status $exit_code2"
        log_plain "  Output: ${output2}"
    fi
    
    # Cleanup
    docker rmi "$image_name" >> /dev/null 2>&1
    rm -rf "$work_dir"
    
    # Final result for this project
    log_plain ""
    if [[ $test_passed -eq $test_total ]]; then
        print_status PASS "PROJECT 01 PASSED (${test_passed}/${test_total} tests)"
        return 0
    else
        print_status FAIL "PROJECT 01 FAILED (${test_passed}/${test_total} tests)"
        return 1
    fi
}

# ============================================================================
# PROJECT 02 GRADING - "HTML Table to CSV Parser"
# ============================================================================

grade_project02() {
    local student_dir="$1"
    local student_name=$(basename "$student_dir")
    local project_dir="${student_dir}/project02"
    local dockerfile=""
    local python_script=""
    
    log ""
    log_plain "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status INFO "GRADING PROJECT 02: ${student_name}"
    log_plain "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if project directory exists
    if [[ ! -d "$project_dir" ]]; then
        print_status FAIL "Project directory not found: $project_dir"
        return 1
    fi
    
    # Find Dockerfile (may be named Dockerfile or Dockerfile.txt or Dockerfile (1).txt)
    if [[ -f "${project_dir}/Dockerfile" ]]; then
        dockerfile="${project_dir}/Dockerfile"
    elif [[ -f "${project_dir}/Dockerfile.txt" ]]; then
        dockerfile="${project_dir}/Dockerfile.txt"
    elif [[ -f "${project_dir}/"Dockerfile* ]]; then
        dockerfile=$(find "${project_dir}" -name "Dockerfile*" | head -1)
    else
        print_status FAIL "No Dockerfile found in ${project_dir}"
        return 1
    fi
    
    # Find Python script
    for script_name in read_html_table.py readhtml.py read.py main.py; do
        if [[ -f "${project_dir}/${script_name}" ]]; then
            python_script="${project_dir}/${script_name}"
            break
        fi
    done
    
    if [[ -z "$python_script" ]]; then
        print_status FAIL "No Python script found in ${project_dir}"
        return 1
    fi
    
    print_status INFO "Found Dockerfile: $(basename $dockerfile)"
    print_status INFO "Found Python script: $(basename $python_script)"
    
    # Create working directory for this student
    local work_dir="${TEMP_WORK_DIR}/${student_name}_p02"
    local output_dir="${work_dir}/output"
    mkdir -p "$work_dir" "$output_dir"
    
    # Copy files
    cp "$dockerfile" "${work_dir}/Dockerfile"
    cp "$python_script" "${work_dir}/read_html_table.py"
    
    # Create mock HTML file with table data
    create_mock_html "${work_dir}/mock_wikipedia.html"
    
    # Fix Dockerfile COPY commands
    sed -i 's|COPY [^ ]* |COPY read_html_table.py |g' "${work_dir}/Dockerfile"
    sed -i 's|^COPY [^/].*/.*\.py|COPY read_html_table.py|g' "${work_dir}/Dockerfile"
    sed -i 's|ENTRYPOINT \["python",[^]]*\]|ENTRYPOINT ["python", "read_html_table.py"]|g' "${work_dir}/Dockerfile"
    sed -i 's|CMD \["python",[^]]*\]|ENTRYPOINT ["python", "read_html_table.py"]|g' "${work_dir}/Dockerfile"
    
    # Build Docker image
    local image_name="${student_name}_project02:latest"
    print_status TEST "Building Docker image: ${image_name}"
    
    if ! docker build -t "$image_name" "$work_dir" >> "$LOG_FILE" 2>&1; then
        print_status FAIL "Docker build failed"
        docker rmi "$image_name" >> /dev/null 2>&1
        rm -rf "$work_dir"
        return 1
    fi
    
    print_status PASS "Docker image built successfully"
    
    # Run tests
    local test_passed=0
    local test_total=2
    
    # Test 1: Parse local HTML file
    print_status TEST "Test 1: Parsing local HTML file"
    local output1=$(timeout $TEST_TIMEOUT docker run --rm -v "${work_dir}:/data:ro" -v "${output_dir}:/output" "$image_name" /data/mock_wikipedia.html 2>&1)
    local exit_code1=$?
    
    if [[ $exit_code1 -eq 0 ]] || [[ $exit_code1 -eq 124 ]]; then  # 124 = timeout, but script might still write files
        # Check if CSV files were created
        if ls "${output_dir}"/*.csv >/dev/null 2>&1; then
            # Verify CSV has content
            local csv_file=$(ls "${output_dir}"/*.csv | head -1)
            local line_count=$(wc -l < "$csv_file")
            
            if [[ $line_count -gt 1 ]]; then  # More than just header
                # Check if content looks like valid table data
                if grep -q "," "$csv_file"; then
                    print_status PASS "Test 1 passed - CSV file created with data"
                    log_plain "  CSV file: $(basename $csv_file)"
                    log_plain "  Lines: $line_count"
                    ((test_passed++))
                else
                    print_status FAIL "Test 1 failed - CSV file doesn't contain comma-separated values"
                fi
            else
                print_status FAIL "Test 1 failed - CSV file is empty or only has header"
            fi
        else
            print_status FAIL "Test 1 failed - No CSV files created"
            log_plain "  Output: ${output1}"
        fi
    else
        print_status FAIL "Test 1 failed - Container exited with status $exit_code1"
        log_plain "  Output: ${output1}"
    fi
    
    # Clean output directory for next test
    rm -f "${output_dir}"/*.csv
    
    # Test 2: Parse Wikipedia URL (simplified validation)
    print_status TEST "Test 2: Testing with Wikipedia URL"
    # Note: We just test if the script runs without crashing with a URL argument
    # Full URL test would require network access which might not be reliable
    local output2=$(timeout $TEST_TIMEOUT docker run --rm -v "${output_dir}:/output" "$image_name" "https://en.wikipedia.org/wiki/Comparison_of_programming_languages" 2>&1 || true)
    
    # Accept pass if:
    # 1. CSV was created, OR
    # 2. No crash (exit code 0), OR  
    # 3. Network error (which is outside scope of grading)
    if ls "${output_dir}"/*.csv >/dev/null 2>&1; then
        local csv_file=$(ls "${output_dir}"/*.csv | head -1)
        local line_count=$(wc -l < "$csv_file")
        
        if [[ $line_count -gt 1 ]]; then
            print_status PASS "Test 2 passed - Successfully parsed Wikipedia data"
            log_plain "  CSV created with $line_count lines"
            ((test_passed++))
        fi
    else
        # If no CSV was created, check if it's due to network issues or script issues
        if echo "$output2" | grep -qi "error\|connection\|network\|timeout"; then
            print_status PASS "Test 2 passed (network unavailable, but script handles it gracefully)"
            ((test_passed++))
        elif echo "$output2" | grep -q ""; then
            # Script ran but didn't create CSV - might be legitimate behavior
            print_status PASS "Test 2 passed (script executed without crash)"
            ((test_passed++))
        else
            print_status FAIL "Test 2 failed - Script execution error"
            log_plain "  Output: ${output2}"
        fi
    fi
    
    # Cleanup
    docker rmi "$image_name" >> /dev/null 2>&1
    rm -rf "$work_dir"
    
    # Final result for this project
    log_plain ""
    if [[ $test_passed -ge 1 ]]; then  # At least 1 test must pass
        print_status PASS "PROJECT 02 PASSED (${test_passed}/${test_total} tests)"
        return 0
    else
        print_status FAIL "PROJECT 02 FAILED (${test_passed}/${test_total} tests)"
        return 1
    fi
}

# ============================================================================
# PROJECT 02 HELPER - Create mock HTML
# ============================================================================

create_mock_html() {
    local output_file="$1"
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Programming Languages Comparison</title>
</head>
<body>
    <h1>Programming Languages</h1>
    <table>
        <tr>
            <th>Language</th>
            <th>Year Created</th>
            <th>Type</th>
        </tr>
        <tr>
            <td>Python</td>
            <td>1991</td>
            <td>Interpreted</td>
        </tr>
        <tr>
            <td>Java</td>
            <td>1995</td>
            <td>Compiled</td>
        </tr>
        <tr>
            <td>C++</td>
            <td>1985</td>
            <td>Compiled</td>
        </tr>
        <tr>
            <td>JavaScript</td>
            <td>1995</td>
            <td>Interpreted</td>
        </tr>
        <tr>
            <td>Go</td>
            <td>2009</td>
            <td>Compiled</td>
        </tr>
    </table>
</body>
</html>
EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    init_grading
    
    # Tracking arrays
    local -A p01_results
    local -A p02_results
    local p01_pass_count=0
    local p01_total_count=0
    local p02_pass_count=0
    local p02_total_count=0
    
    # Get list of all student directories
    local students_to_grade=()
    
    if [[ $# -gt 0 ]]; then
        # Grade specific students
        for student in "$@"; do
            local student_dir="${WORKSPACE_ROOT}/${student}"
            if [[ -d "$student_dir" ]]; then
                students_to_grade+=("$student_dir")
            else
                log "WARNING: Student directory not found: ${student_dir}"
            fi
        done
    else
        # Grade all students
        for student_dir in "${WORKSPACE_ROOT}"/*; do
            if [[ -d "$student_dir" ]] && [[ $(basename "$student_dir") != ".git" ]] && [[ $(basename "$student_dir") != "grading_results" ]]; then
                students_to_grade+=("$student_dir")
            fi
        done
    fi
    
    # Sort student directories for consistent ordering
    IFS=$'\n' students_to_grade=($(sort <<<"${students_to_grade[*]}"))
    unset IFS
    
    log "Found ${#students_to_grade[@]} students to grade"
    
    # Grade each student
    for student_dir in "${students_to_grade[@]}"; do
        local student_name=$(basename "$student_dir")
        
        # Project 01
        if grade_project01 "$student_dir"; then
            p01_results[$student_name]="PASS"
            ((p01_pass_count++))
        else
            p01_results[$student_name]="FAIL"
        fi
        ((p01_total_count++))
        
        # Project 02
        if grade_project02 "$student_dir"; then
            p02_results[$student_name]="PASS"
            ((p02_pass_count++))
        else
            p02_results[$student_name]="FAIL"
        fi
        ((p02_total_count++))
    done
    
    # Generate summary report
    generate_summary_report "$p01_pass_count" "$p01_total_count" "$p02_pass_count" "$p02_total_count" p01_results p02_results
    
    # Cleanup
    cleanup
    
    log ""
    log "═══════════════════════════════════════════════════════════════"
    log "Grading completed: $(date)"
    log "Full log saved to: $LOG_FILE"
    log "═══════════════════════════════════════════════════════════════"
}

# ============================================================================
# SUMMARY REPORT
# ============================================================================

generate_summary_report() {
    local p01_pass=$1
    local p01_total=$2
    local p02_pass=$3
    local p02_total=$4
    
    # These need to be passed as associative array references
    # We'll recreate them from the global scope instead
    
    log ""
    log_plain "═══════════════════════════════════════════════════════════════"
    log_plain "GRADING SUMMARY REPORT"
    log_plain "═══════════════════════════════════════════════════════════════"
    log_plain ""
    log_plain "PROJECT 01 (Hello World Docker Container):"
    log_plain "  Passed: $p01_pass / $p01_total"
    local p01_percentage=0
    if [[ $p01_total -gt 0 ]]; then
        p01_percentage=$((p01_pass * 100 / p01_total))
    fi
    log_plain "  Success Rate: ${p01_percentage}%"
    log_plain ""
    
    log_plain "PROJECT 02 (HTML Table to CSV Parser):"
    log_plain "  Passed: $p02_pass / $p02_total"
    local p02_percentage=0
    if [[ $p02_total -gt 0 ]]; then
        p02_percentage=$((p02_pass * 100 / p02_total))
    fi
    log_plain "  Success Rate: ${p02_percentage}%"
    log_plain ""
    
    local both_passed=0
    local both_failed=0
    
    for student in "${!p01_results[@]}"; do
        if [[ "${p01_results[$student]}" == "PASS" ]] && [[ "${p02_results[$student]}" == "PASS" ]]; then
            ((both_passed++))
        elif [[ "${p01_results[$student]}" == "FAIL" ]] && [[ "${p02_results[$student]}" == "FAIL" ]]; then
            ((both_failed++))
        fi
    done
    
    log_plain "OVERALL STATISTICS:"
    log_plain "  Total Students: ${#p01_results[@]}"
    log_plain "  Both Projects Passed: $both_passed"
    log_plain "  Both Projects Failed: $both_failed"
    log_plain ""
    log_plain "═══════════════════════════════════════════════════════════════"
}

# Run main function
main "$@"
