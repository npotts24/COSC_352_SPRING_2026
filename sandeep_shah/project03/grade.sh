#!/bin/bash

###############################################
# Docker Auto Grader - Single Project Mode
###############################################

# ========== CONFIG ==========
SUBMISSIONS_DIR="./submissions"
INPUT_DIR="./inputs"
EXPECTED_DIR="./expected"
PROJECT_NAME="project03"

LOG_FILE="grading_$(date +%Y%m%d_%H%M%S).log"
TIME_LIMIT=10
MAX_SCORE=100

# ========== LOG FUNCTION ==========
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# ========== START ==========
log "========================================"
log " Grading Started for $PROJECT_NAME"
log "========================================"

total_students=0
total_passed=0
total_failed=0

for student_path in "$SUBMISSIONS_DIR"/*; do

    student=$(basename "$student_path")
    total_students=$((total_students + 1))
    score=$MAX_SCORE
    image_tag="${student}_${PROJECT_NAME}_img"

    log "\n----------------------------------------"
    log "Grading: $student"
    log "----------------------------------------"

    # Check if Dockerfile exists
    if [ ! -f "$student_path/Dockerfile" ]; then
        log "  ❌ Missing Dockerfile"
        score=$((score - 30))
        continue
    fi

    # ===== BUILD IMAGE =====
    docker build -t "$image_tag" "$student_path" >>"$LOG_FILE" 2>&1

    if [ $? -ne 0 ]; then
        log "  ❌ Build failed"
        score=$((score - 30))
        continue
    fi

    log "  ✔ Build successful"

    # ===== RUN TESTS =====
    for input_file in "$INPUT_DIR"/*.in; do

        test_name=$(basename "$input_file" .in)
        expected_file="$EXPECTED_DIR/$test_name.out"
        actual_output="tmp_${student}_${test_name}.out"

        log "  Running Test: $test_name"

        timeout "$TIME_LIMIT" docker run -i --rm "$image_tag" \
            < "$input_file" > "$actual_output" 2>>"$LOG_FILE"

        if [ $? -ne 0 ]; then
            log "    ❌ Runtime failure or timeout"
            score=$((score - 10))
            continue
        fi

        diff -q "$actual_output" "$expected_file" >/dev/null 2>&1

        if [ $? -eq 0 ]; then
            log "    ✔ PASS"
        else
            log "    ❌ FAIL"
            score=$((score - 10))
        fi

        rm -f "$actual_output"

    done

    # ===== CLEANUP =====
    docker rmi "$image_tag" >/dev/null 2>&1

    if [ "$score" -lt 0 ]; then
        score=0
    fi

    if [ "$score" -ge 60 ]; then
        total_passed=$((total_passed + 1))
    else
        total_failed=$((total_failed + 1))
    fi

    log "Final Score for $student: $score / $MAX_SCORE"

done

# ===== SUMMARY =====
log "\n========================================"
log " FINAL SUMMARY"
log "========================================"
log "Total Students: $total_students"
log "Passed: $total_passed"
log "Failed: $total_failed"
log "Log File: $LOG_FILE"
log "========================================"
