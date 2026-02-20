#!/bin/bash

LOG_FILE="grading.log"
> $LOG_FILE

# Test input/output files
TEST_INPUTS=("test1.in" "test2.in" "test3.in" "test4.in")
EXPECTED_OUTPUTS=("test1.out" "test2.out" "test3.out" "test4.out")

# Current student/project
STUDENT_NAME="rochak_ghimire"
PROJECT_DIR="."  # grading current folder

echo "Grading student: $STUDENT_NAME" | tee -a $LOG_FILE
cd "$PROJECT_DIR"

IMAGE_NAME="project3_test_img"

# Build Docker image
echo "Building Docker image..." | tee -a $LOG_FILE
if docker build -t $IMAGE_NAME . | tee -a $LOG_FILE; then
    echo "Docker build SUCCESS" | tee -a $LOG_FILE
else
    echo "Docker build FAILED" | tee -a $LOG_FILE
    exit 1
fi

PASSED=0
FAILED=0

# Run all test cases
for i in "${!TEST_INPUTS[@]}"; do
    INPUT_FILE="${TEST_INPUTS[$i]}"
    EXPECTED_FILE="${EXPECTED_OUTPUTS[$i]}"

    echo "Running test: $INPUT_FILE" | tee -a $LOG_FILE

    # Run container and capture output (Mac compatible)
    OUTPUT=$(docker run --rm -i $IMAGE_NAME python main.py < $INPUT_FILE 2>&1)

    # Normalize line endings and trim trailing whitespace for comparison
    NORMAL_OUTPUT=$(echo "$OUTPUT" | tr -d '\r' | sed 's/[[:space:]]*$//')
    NORMAL_EXPECTED=$(cat $EXPECTED_FILE | tr -d '\r' | sed 's/[[:space:]]*$//')

    # Compare outputs
    if [ "$NORMAL_OUTPUT" == "$NORMAL_EXPECTED" ]; then
        echo "Test $INPUT_FILE → PASSED" | tee -a $LOG_FILE
        ((PASSED++))
    else
        echo "Test $INPUT_FILE → FAILED" | tee -a $LOG_FILE
        echo "Expected output:" | tee -a $LOG_FILE
        echo "$NORMAL_EXPECTED" | tee -a $LOG_FILE
        echo "Actual output:" | tee -a $LOG_FILE
        echo "$NORMAL_OUTPUT" | tee -a $LOG_FILE
        ((FAILED++))
    fi
done

echo "-----------------------------------" | tee -a $LOG_FILE
echo "Summary for $STUDENT_NAME: Passed: $PASSED  Failed: $FAILED" | tee -a $LOG_FILE
echo "-----------------------------------" | tee -a $LOG_FILE

# Clean up Docker image
docker rmi -f $IMAGE_NAME >/dev/null 2>&1

