#!/bin/bash

#Calling Variables.

PROJECT_DIR=$1
LOG_FILE="grading_log_$(date +%Y%m%d).txt"

# Initial Validation process.

if [ -z "$PROJECT_DIR" ]; then
  echo "Usage: $0 <project_directory>"
  exit 1
fi

echo "Starting the grading process: $(date)" | tee "$LOG_FILE"
echo "Project: $PROJECT_DIR" | tee -a "$LOG_FILE"

TOTAL=0
PASSED=0

# Main for loop.


for student_dir in "$PROJECT_DIR"/*/; do
    [ -e "$student_dir" ] || continue

    STUDENT=$(basename "$student_dir")
    TOTAL=$((TOTAL + 1))

    echo -e "\nGrading student: $STUDENT" | tee -a "$LOG_FILE"

# Starting Docker process


    IMAGE_NAME="grading_$(echo "$STUDENT" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"
    if ! docker build -t "$IMAGE_NAME" "$student_dir" > /dev/null 2>build_error.log; then
        echo "build failed for $STUDENT. See build_error.log for details." | tee -a "$LOG_FILE"
        continue
    fi

    if [[ -f "$PROJECT_DIR/test_input.txt" && -f "$PROJECT_DIR/expected_output.txt" ]]; then


# Preventing infinite loops. 

        ACTUAL_OUTPUT=$(timeout 5s docker run --rm -i "$IMAGE_NAME" < "$PROJECT_DIR/test_input.txt" 2>/dev/null || true)

        DIFF=$(echo "$ACTUAL_OUTPUT" | diff -w - "$PROJECT_DIR/expected_output.txt" || true)

        if [ -z "$DIFF" ]; then
            echo "Test passed for $STUDENT." | tee -a "$LOG_FILE"
            PASSED=$((PASSED + 1))
        else
            echo "Test failed for $STUDENT. Output differs from expected." | tee -a "$LOG_FILE"
        fi
    else
        echo "No test input or expected output found. Skipping test for $STUDENT." | tee -a "$LOG_FILE"
    fi

# Clean up process.

    docker rmi "$IMAGE_NAME" > /dev/null 2>&1 || true
done

echo -e "\nGrading completed: $(date)" | tee -a "$LOG_FILE"
echo "Total students: $TOTAL" | tee -a "$LOG_FILE"
echo "Passed: $PASSED" | tee -a "$LOG_FILE"