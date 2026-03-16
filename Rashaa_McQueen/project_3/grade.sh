#!/bin/bash

#############################################
# COSC 352 Docker Auto Grader
# Works with structure:
# students/student_name/project01
# students/student_name/project02
#############################################

BASE_DIR="$(pwd)"
STUDENT_DIR="$BASE_DIR/students"
TEST_DIR="$BASE_DIR/tests"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/grading.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

PROJECTS=("project01" "project02")

TOTAL=0
PASS=0
FAIL=0

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

grade_project() {

    student="$1"
    project="$2"
    project_path="$STUDENT_DIR/$student/$project"

    if [ ! -d "$project_path" ]; then
        log "   ❌ $project not found"
        return
    fi

    image="${student}_${project}_img"

    log "   🔨 Building $project..."
    docker build -t "$image" "$project_path" >> "$LOG_FILE" 2>&1

    if [ $? -ne 0 ]; then
        log "   ❌ Build failed"
        FAIL=$((FAIL+1))
        return
    fi

    score=100

    for input in "$TEST_DIR/$project"/*.input; do

        [ -f "$input" ] || continue

        testname=$(basename "$input" .input)
        expected="$TEST_DIR/$project/$testname.expected"

        log "      ▶ Test: $testname"

        output=$(timeout 5 docker run --rm -i "$image" < "$input" 2>>"$LOG_FILE")

        if [ $? -ne 0 ]; then
            log "      ❌ Runtime error"
            score=$((score-30))
            continue
        fi

        echo "$output" > actual.tmp

        if diff actual.tmp "$expected" >/dev/null; then
            log "      ✅ PASS"
        else
            log "      ❌ FAIL"
            score=$((score-10))
        fi
    done

    rm -f actual.tmp
    docker rmi -f "$image" >> "$LOG_FILE" 2>&1

    log "   📊 Score: $score"
    log "--------------------------------"

    if [ $score -ge 60 ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
    fi
}

log "🚀 STARTING GRADING"
log "================================"

for student_path in "$STUDENT_DIR"/*; do

    [ -d "$student_path" ] || continue

    student=$(basename "$student_path")

    TOTAL=$((TOTAL+1))

    log ""
    log "👤 Student: $student"

    for project in "${PROJECTS[@]}"; do
        grade_project "$student" "$project"
    done

done

log ""
log "============= SUMMARY ============="
log "Total Students: $TOTAL"
log "Passed: $PASS"
log "Failed: $FAIL"
log "==================================="
