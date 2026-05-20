#!/bin/bash
# Test script for HTML Table Parser
# This script runs various tests to validate the program works correctly

echo "=========================================="
echo "HTML Table Parser - Test Suite"
echo "=========================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_result="$3"
    
    echo "Test: $test_name"
    echo "Running: $command"
    
    if eval "$command"; then
        if [ "$expected_result" = "should_succeed" ]; then
            echo -e "${GREEN}✓ PASS${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL (expected failure but succeeded)${NC}"
            ((TESTS_FAILED++))
        fi
    else
        if [ "$expected_result" = "should_fail" ]; then
            echo -e "${GREEN}✓ PASS (failed as expected)${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${RED}✗ FAIL${NC}"
            ((TESTS_FAILED++))
        fi
    fi
    echo ""
}

# Test 1: Help command
run_test "Help command" \
    "python read_html_table.py --help > /dev/null" \
    "should_succeed"

# Test 2: Parse test_example.html
run_test "Parse test_example.html" \
    "python read_html_table.py test_example.html test_output > /dev/null" \
    "should_succeed"

# Test 3: Verify output files exist
run_test "Output files created" \
    "[ -f test_output_table_1.csv ] && [ -f test_output_table_2.csv ]" \
    "should_succeed"

# Test 4: Check CSV content
run_test "CSV content validation" \
    "grep -q 'Language' test_output_table_1.csv && grep -q 'Python' test_output_table_1.csv" \
    "should_succeed"

# Test 5: Error handling - nonexistent file
run_test "Error handling (nonexistent file)" \
    "python read_html_table.py nonexistent.html 2>/dev/null" \
    "should_fail"

# Test 6: Count rows in output
ROW_COUNT=$(wc -l < test_output_table_1.csv)
if [ "$ROW_COUNT" -eq 6 ]; then
    echo "Test: Row count validation"
    echo "Expected 6 rows, got $ROW_COUNT"
    echo -e "${GREEN}✓ PASS${NC}"
    ((TESTS_PASSED++))
else
    echo "Test: Row count validation"
    echo "Expected 6 rows, got $ROW_COUNT"
    echo -e "${RED}✗ FAIL${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Clean up test files
echo "Cleaning up test files..."
rm -f test_output_table_*.csv
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed! ✗${NC}"
    exit 1
fi
