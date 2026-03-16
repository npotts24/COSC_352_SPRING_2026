#!/bin/bash

# ========================================
# CONFIGURATION
# ========================================

PROJECT="$1"

if [ -z "$PROJECT" ]; then
    echo "Usage: ./grade.sh project01"
    exit 1
fi

STUDENT_DIR="./students"
TEST_DIR="./tests/$PROJECT"
LOG_FILE="grading_${PROJECT}_$(date +%Y%m%d_%H%M%S).log"

PASS=0
FAIL=0
TOTAL=0

echo "========================================" | tee "$LOG_FILE"
echo " Grading Started for $PROJECT" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# ========================================
# FUNCTION: GRADE STUDENT
# ========================================

grade_student() {

    STUDENT_PATH="$1"
    STUDENT_NAME=$(basename "$STUDENT_PATH")
    IMAGE_NAME="${STUDENT_NAME}_${PROJECT}_img"

    echo "" | tee -a "$LOG_FILE"
    echo "Grading: $STUDENT_NAME" | tee -a "$LOG_FILE"

    # Build Docker image
    docker build -t "$IMAGE_NAME" "$STUDENT_PATH" >> "$LOG_FILE" 2>&1

    if [ $? -ne 0 ]; then
        echo "BUILD FAILED for $STUDENT_NAME" | tee -a "$LOG_FILE"
        FAIL=$((FAIL+1))
        return
    fi

    # Run all test cases
    for INPUT_FILE in "$TEST_DIR"/input*.txt; do

        TEST_NUM=$(basename "$INPUT_FILE" | sed 's/input//; s/.txt//')
        EXPECTED_FILE="$TEST_DIR/expected${TEST_NUM}.txt"

        TOTAL=$((TOTAL+1))

        ARGS=$(cat "$INPUT_FILE")

        OUTPUT=$(timeout 5 docker run --rm "$IMAGE_NAME" $ARGS 2>&1)

        # Trim whitespace for safer comparison
        CLEAN_OUTPUT=$(echo "$OUTPUT" | tr -d '\r' | sed '/^$/d' | sed 's/[[:space:]]*$//')
        CLEAN_EXPECTED=$(cat "$EXPECTED_FILE" | tr -d '\r' | sed '/^$/d' | sed 's/[[:space:]]*$//')

        if diff <(echo "$CLEAN_OUTPUT") <(echo "$CLEAN_EXPECTED") > /dev/null; then
            echo "$STUDENT_NAME Test $TEST_NUM: PASS" | tee -a "$LOG_FILE"
            PASS=$((PASS+1))
        else
            echo "$STUDENT_NAME Test $TEST_NUM: FAIL" | tee -a "$LOG_FILE"
            echo "  Expected: $CLEAN_EXPECTED" >> "$LOG_FILE"
            echo "  Got: $CLEAN_OUTPUT" >> "$LOG_FILE"
            FAIL=$((FAIL+1))
        fi
    done

    # Cleanup
    docker rmi -f "$IMAGE_NAME" >> "$LOG_FILE" 2>&1
}

# ========================================
# MAIN LOOP
# ========================================

for STUDENT in "$STUDENT_DIR"/*; do
    [ -d "$STUDENT" ] || continue
    grade_student "$STUDENT"
done

# ========================================
# FINAL SUMMARY
# ========================================

echo "" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "FINAL SUMMARY" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"
echo "Total Tests: $TOTAL" | tee -a "$LOG_FILE"
echo "Passed: $PASS" | tee -a "$LOG_FILE"
echo "Failed: $FAIL" | tee -a "$LOG_FILE"

if [ "$TOTAL" -gt 0 ]; then
    SCORE=$((PASS * 100 / TOTAL))
else
    SCORE=0
fi

echo "Overall Score: $SCORE%" | tee -a "$LOG_FILE"

echo "Grading complete. Log saved to $LOG_FILE"
