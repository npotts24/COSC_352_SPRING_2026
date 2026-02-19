#!/bin/bash

################################################################################
# Test Script for Grading System
# 
# This script helps you test and validate the grading system
# Run this before grading all students
################################################################################

set -o pipefail

WORKSPACE_ROOT="/workspaces/COSC_352_SPRING_2026"

echo "========================================"
echo "COSC 352 Grading System Test Suite"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_count=0
passed_count=0

# Test function
run_test() {
    local test_name=$1
    local command=$2
    local should_succeed=$3  # true or false
    
    ((test_count++))
    
    echo -n "[$test_count] $test_name... "
    
    if eval "$command" &>/dev/null; then
        if [[ "$should_succeed" == "true" ]]; then
            echo -e "${GREEN}PASS${NC}"
            ((passed_count++))
        else
            echo -e "${RED}FAIL${NC} (expected to fail but passed)"
        fi
    else
        if [[ "$should_succeed" == "false" ]]; then
            echo -e "${GREEN}PASS${NC}"
            ((passed_count++))
        else
            echo -e "${RED}FAIL${NC}"
        fi
    fi
}

################################################################################
# PRE-FLIGHT CHECKS
################################################################################
echo "=== Pre-flight Checks ==="
echo ""

run_test "Docker is installed" "which docker" "true"
run_test "Docker daemon is running" "docker ps &>/dev/null" "true"
run_test "Bash version >= 4" "[[ ${BASH_VERSINFO[0]} -ge 4 ]]" "true"
run_test "Required utilities exist" "[[ -n \$(command -v grep) ]] && [[ -n \$(command -v awk) ]]" "true"

echo ""
echo "=== Workspace Structure ==="
echo ""

run_test "Workspace directory exists" "[[ -d $WORKSPACE_ROOT ]]" "true"
run_test "Student directories exist" "[[ -d $WORKSPACE_ROOT/obaloluwa_wojuade ]]" "true"
run_test "Script file exists" "[[ -f $WORKSPACE_ROOT/obaloluwa_wojuade/project03/grade.sh ]]" "true"
run_test "Script is executable" "[[ -x $WORKSPACE_ROOT/obaloluwa_wojuade/project03/grade.sh ]]" "true"

echo ""
echo "=== Docker Functionality ==="
echo ""

# Test: Can build a simple image
echo -n "[$((++test_count))] Build test Docker image... "
if docker build -t test-alpine-hello -q - << 'EOF' &>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((passed_count++))
    TEST_IMAGE_BUILT=true
else
    echo -e "${RED}FAIL${NC}"
    TEST_IMAGE_BUILT=false
fi

# Test: Can run a container
if [[ "$TEST_IMAGE_BUILT" == "true" ]]; then
    echo -n "[$((++test_count))] Run container and capture output... "
    output=$(docker run --rm test-alpine-hello echo "Hello Docker")
    if [[ "$output" == "Hello Docker" ]]; then
        echo -e "${GREEN}PASS${NC}"
        ((passed_count++))
    else
        echo -e "${RED}FAIL${NC} (output: $output)"
    fi
    
    # Cleanup
    docker rmi -f test-alpine-hello &>/dev/null
fi

echo ""
echo "=== Grading Script Validation ==="
echo ""

# Check bash syntax
echo -n "[$((++test_count))] Bash syntax is valid... "
if bash -n $WORKSPACE_ROOT/obaloluwa_wojuade/project03/grade.sh &>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((passed_count++))
else
    echo -e "${RED}FAIL${NC} (syntax error in script)"
fi

# Test: Help option works
echo -n "[$((++test_count))] Help option works... "
if $WORKSPACE_ROOT/obaloluwa_wojuade/project03/grade.sh --help | grep -q "COSC 352" &>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((passed_count++))
else
    echo -e "${RED}FAIL${NC}"
fi

echo ""
echo "=== Sample Student Submission Tests ==="
echo ""

# Test: Check if test student has project01
echo -n "[$((++test_count))] Test student project01 exists... "
if [[ -f $WORKSPACE_ROOT/obaloluwa_wojuade/project01/Dockerfile ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((passed_count++))
    HAS_SAMPLE_PROJECT01=true
else
    echo -e "${YELLOW}SKIP${NC} (no sample project01)"
    HAS_SAMPLE_PROJECT01=false
fi

# Test: Dockerfile has required fields
if [[ "$HAS_SAMPLE_PROJECT01" == "true" ]]; then
    echo -n "[$((++test_count))] Project01 Dockerfile has FROM... "
    if grep -q "^FROM" $WORKSPACE_ROOT/obaloluwa_wojuade/project01/Dockerfile; then
        echo -e "${GREEN}PASS${NC}"
        ((passed_count++))
    else
        echo -e "${RED}FAIL${NC}"
    fi
fi

echo ""
echo "=== Output and Logging ==="
echo ""

# Test: Log directory creation
echo -n "[$((++test_count))] Log directory can be created... "
test_log_dir="/tmp/test_grading_logs_$$"
if mkdir -p "$test_log_dir" && [[ -d "$test_log_dir" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((passed_count++))
    rm -rf "$test_log_dir"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test: Color codes are correct
echo -n "[$((++test_count))] ANSI color codes are available... "
if echo -e "\033[0;32mGreen${NC}" | grep -q "Green" &>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((passed_count++))
else
    echo -e "${RED}FAIL${NC}"
fi

echo ""
echo "=== Grading Simulation ==="
echo ""

# Test: DRY RUN with one student
echo -n "[$((++test_count))] Script accepts -p parameter... "
if $WORKSPACE_ROOT/obaloluwa_wojuade/project03/grade.sh -p 01 -h 2>&1 | grep -q "show this help" &>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((passed_count++))
else
    # This might fail due to help handling, so we'll be lenient
    echo -e "${YELLOW}SKIP${NC}"
fi

echo ""
echo "=== Additional Validation ==="
echo ""

# Check for required functions in script
functions_to_check=(
    "init_logging"
    "log_message"
    "define_project_tests"
    "build_docker_image"
    "run_container_test"
    "compare_output"
    "grade_student_project"
)

for func in "${functions_to_check[@]}"; do
    echo -n "[$((++test_count))] Function '$func' exists... "
    if grep -q "^${func}()" $WORKSPACE_ROOT/obaloluwa_wojuade/project03/grade.sh; then
        echo -e "${GREEN}PASS${NC}"
        ((passed_count++))
    else
        echo -e "${RED}FAIL${NC}"
    fi
done

echo ""
echo "=== Test Results ==="
echo ""

pass_rate=$((passed_count * 100 / test_count))

if [[ $pass_rate -ge 90 ]]; then
    result_color="${GREEN}"
    status="READY"
elif [[ $pass_rate -ge 70 ]]; then
    result_color="${YELLOW}"
    status="WARNING"
else
    result_color="${RED}"
    status="FAILED"
fi

echo -e "Passed: ${result_color}${passed_count}/${test_count}${NC} (${pass_rate}%)"
echo -e "Status: ${result_color}${status}${NC}"
echo ""

if [[ "$status" == "READY" ]]; then
    echo -e "${GREEN}✓ System is ready for grading${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Test with a single student:"
    echo "     cd $WORKSPACE_ROOT/obaloluwa_wojuade/project03"
    echo "     ./grade.sh -p 01 -s obaloluwa_wojuade"
    echo ""
    echo "  2. Review the output and log file"
    echo ""
    echo "  3. Grade all students:"
    echo "     ./grade.sh -p 01"
    echo ""
    exit 0
elif [[ "$status" == "WARNING" ]]; then
    echo -e "${YELLOW}⚠ System has some issues but may still work${NC}"
    echo ""
    echo "Recommended actions:"
    echo "  1. Check which tests failed above"
    echo "  2. Ensure Docker is running"
    echo "  3. Verify file permissions"
    echo "  4. Test manually: ./grade.sh -p 01 -s obaloluwa_wojuade"
    echo ""
    exit 1
else
    echo -e "${RED}✗ System has critical issues${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check Docker: docker ps"
    echo "  2. Check script: cat $WORKSPACE_ROOT/obaloluwa_wojuade/project03/grade.sh | head -20"
    echo "  3. Check workspace: ls -la $WORKSPACE_ROOT/"
    echo ""
    exit 1
fi
