#!/bin/bash

# grade.sh - Automated Docker grading script

# Students and projects
STUDENTS=("Jhon" "Jack" "Harry" "Iqbal")
PROJECTS=("project01" "project02")

# Log file
LOGFILE="logs/grade_results.log"
mkdir -p logs
> "$LOGFILE"  # Clear previous log

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "=== Automated Grading Started ===" | tee -a "$LOGFILE"

for PROJECT in "${PROJECTS[@]}"; do
    echo "Grading $PROJECT..." | tee -a "$LOGFILE"
    
    for STUDENT in "${STUDENTS[@]}"; do
        # Lowercase image name for Docker
        IMAGE_NAME="${STUDENT,,}_${PROJECT,,}"
        EXPECTED_FILE="autograder_tests/${PROJECT}/expected/${STUDENT}.txt"
        STUDENT_PATH="students/student1/$PROJECT"

        echo "--- $STUDENT ---" | tee -a "$LOGFILE"

        # Check if expected file exists
        if [ ! -f "$EXPECTED_FILE" ]; then
            echo "Expected output for $STUDENT in $PROJECT not found!" | tee -a "$LOGFILE"
            ((FAILED_TESTS++))
            continue
        fi

        # Check if student project folder exists
        if [ ! -d "$STUDENT_PATH" ]; then
            echo "Project folder for $STUDENT in $PROJECT not found!" | tee -a "$LOGFILE"
            ((FAILED_TESTS++))
            continue
        fi

        # Build Docker image
        echo "Building Docker image $IMAGE_NAME..." | tee -a "$LOGFILE"
        docker build -t "$IMAGE_NAME" "$STUDENT_PATH"
        if [ $? -ne 0 ]; then
            echo "Build failed for $STUDENT in $PROJECT" | tee -a "$LOGFILE"
            ((FAILED_TESTS++))
            continue
        fi

        # Run Docker container with student name as argument
        OUTPUT=$(docker run --rm "$IMAGE_NAME" "$STUDENT")
        if [ $? -ne 0 ]; then
            echo "Runtime error for $STUDENT in $PROJECT" | tee -a "$LOGFILE"
            ((FAILED_TESTS++))
            docker rmi "$IMAGE_NAME" >/dev/null 2>&1
            continue
        fi

        # Compare output with expected
        EXPECTED=$(cat "$EXPECTED_FILE")
        if [ "$OUTPUT" = "$EXPECTED" ]; then
            echo "PASS: $OUTPUT" | tee -a "$LOGFILE"
            ((PASSED_TESTS++))
        else
            echo "FAIL" | tee -a "$LOGFILE"
            echo "Expected: $EXPECTED" | tee -a "$LOGFILE"
            echo "Got:      $OUTPUT" | tee -a "$LOGFILE"
            ((FAILED_TESTS++))
        fi

        # Clean up Docker image
        docker rmi "$IMAGE_NAME" >/dev/null 2>&1
        ((TOTAL_TESTS++))
    done

    echo "---------------------------" | tee -a "$LOGFILE"
done

# Summary
echo "=== Grading Summary ===" | tee -a "$LOGFILE"
echo "Total tests: $TOTAL_TESTS" | tee -a "$LOGFILE"
echo "Passed:      $PASSED_TESTS" | tee -a "$LOGFILE"
echo "Failed:      $FAILED_TESTS" | tee -a "$LOGFILE"
echo "Log file: $LOGFILE"
