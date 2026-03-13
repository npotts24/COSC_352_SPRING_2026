#!/bin/bash

############################################################
# Project 3 - Regex/Shell Scripting - Class Autograder
# Author: Stephen Waita
# Description:
#   Bash-only Docker autograder for student submissions.
############################################################

########################
# CONFIGURATION
########################

STUDENT_ROOT="./students"          # Folder containing all student directories
LOG_FILE="grading_log.txt"         # Log file
IMAGE_PREFIX="student_image"       # Docker image prefix
TIME_LIMIT=5                       # Max runtime in seconds

# -------- MODIFY FOR FUTURE PROJECTS --------
TEST_INPUT="5 10"
EXPECTED_OUTPUT="15"
# --------------------------------------------

########################
# INITIALIZATION
########################

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

echo "===== Docker Autograder Log =====" > "$LOG_FILE"
echo "Started at: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

########################
# LOG FUNCTION
########################
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

########################
# CLEANUP FUNCTION
########################
cleanup() {
    docker rm -f "$1" >/dev/null 2>&1
    docker rmi -f "$2" >/dev/null 2>&1
}

########################
# GRADE FUNCTION
########################
grade_student() {

    STUDENT_DIR="$1"
    STUDENT_NAME=$(basename "$STUDENT_DIR")
    IMAGE_NAME="${IMAGE_PREFIX}_${STUDENT_NAME}"
    CONTAINER_NAME="container_${STUDENT_NAME}"

    log "--------------------------------------"
    log "Grading: $STUDENT_NAME"
    log "--------------------------------------"

    cd "$STUDENT_DIR" || {
        log "ERROR: Cannot access directory."
        ((FAIL_COUNT++))
        return
    }

    # Build image
    docker build -t "$IMAGE_NAME" . >> "../../$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        log "Build Failed."
        ((FAIL_COUNT++))
        cd - >/dev/null
        return
    fi

    # Run container with input
    ACTUAL_OUTPUT=$(echo "$TEST_INPUT" | timeout "$TIME_LIMIT" docker run --name "$CONTAINER_NAME" -i "$IMAGE_NAME" 2>/dev/null)

    if [ $? -ne 0 ]; then
        log "Runtime Failed or Timed Out."
        cleanup "$CONTAINER_NAME" "$IMAGE_NAME"
        ((FAIL_COUNT++))
        cd - >/dev/null
        return
    fi

    # Trim whitespace
    ACTUAL_OUTPUT=$(echo "$ACTUAL_OUTPUT" | sed 's/[[:space:]]*$//')
    EXPECTED_CLEAN=$(echo "$EXPECTED_OUTPUT" | sed 's/[[:space:]]*$//')

    # Compare outputs
    if diff <(echo "$ACTUAL_OUTPUT") <(echo "$EXPECTED_CLEAN") >/dev/null; then
        log "Result: PASS"
        ((PASS_COUNT++))
    else
        log "Result: FAIL"
        log "Expected: $EXPECTED_CLEAN"
        log "Got: $ACTUAL_OUTPUT"
        ((FAIL_COUNT++))
    fi

    cleanup "$CONTAINER_NAME" "$IMAGE_NAME"
    cd - >/dev/null
}

########################
# MAIN LOOP
########################

log "Beginning grading process..."
log ""

for DIR in "$STUDENT_ROOT"/*; do
    if [ -d "$DIR" ]; then
        ((TOTAL_COUNT++))
        grade_student "$DIR"
    fi
done

########################
# FINAL SUMMARY
########################

log ""
log "========== FINAL SUMMARY =========="
log "Total Students: $TOTAL_COUNT"
log "Passed: $PASS_COUNT"
log "Failed: $FAIL_COUNT"

if [ "$TOTAL_COUNT" -gt 0 ]; then
    SCORE=$((PASS_COUNT * 100 / TOTAL_COUNT))
else
    SCORE=0
fi

log "Class Pass Percentage: $SCORE%"
log "Finished at: $(date)"
log "==================================="