#!/bin/bash

# Load configuration variables
source ./config.sh

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_SCORE=0

echo "Starting grading for $PROJECT" | tee $LOG_FILE
echo "---------------------------------" | tee -a $LOG_FILE

# Loop through each student directory
for student in "$SUBMISSION_DIR"/*; do
    [ -d "$student" ] || continue

    STUDENT_NAME=$(basename "$student")
    IMAGE_NAME="${STUDENT_NAME}_image"

    echo "Grading $STUDENT_NAME..." | tee -a $LOG_FILE

    # Build Docker image
    docker build -t $IMAGE_NAME "$student" >> $LOG_FILE 2>&1

    # If build fails, log error and continue
    if [ $? -ne 0 ]; then
        echo "Build failed for $STUDENT_NAME" | tee -a $LOG_FILE
        FAIL_COUNT=$((FAIL_COUNT+1))
        echo "---------------------------------" | tee -a $LOG_FILE
        continue
    fi

    STUDENT_SCORE=0

    # Loop through test inputs
    for input_file in "$TEST_DIR"/input*.txt; do
        test_number=$(basename "$input_file" | sed 's/input//; s/.txt//')
        expected_file="$TEST_DIR/expected${test_number}.txt"

        # Run container with input and capture output
        ACTUAL_OUTPUT=$(timeout $TIME_LIMIT docker run -i $IMAGE_NAME < "$input_file")

        # Compare output
        if diff <(echo "$ACTUAL_OUTPUT") "$expected_file" > /dev/null; then
            echo "Test $test_number: PASS" | tee -a $LOG_FILE
            STUDENT_SCORE=$((STUDENT_SCORE + POINTS_PER_TEST))
            PASS_COUNT=$((PASS_COUNT+1))
        else
            echo "Test $test_number: FAIL" | tee -a $LOG_FILE
            FAIL_COUNT=$((FAIL_COUNT+1))
        fi
    done

    # Cleanup Docker image
    docker rmi -f $IMAGE_NAME >> $LOG_FILE 2>&1

    echo "$STUDENT_NAME Score: $STUDENT_SCORE" | tee -a $LOG_FILE
    TOTAL_SCORE=$((TOTAL_SCORE + STUDENT_SCORE))
    echo "---------------------------------" | tee -a $LOG_FILE
done

# Final summary
echo "Grading Complete!" | tee -a $LOG_FILE
echo "Total Passed: $PASS_COUNT" | tee -a $LOG_FILE
echo "Total Failed: $FAIL_COUNT" | tee -a $LOG_FILE
echo "Total Score: $TOTAL_SCORE" | tee -a $LOG_FILE
