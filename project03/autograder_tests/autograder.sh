#!/usr/bin/env bash
set -uo pipefail

# Root of the repo (where all student folders live)
CLASS_ROOT="."
# Root of your autograder tests
TESTS_ROOT="project03/autograder_tests"
# Log file location
LOG_FILE="project03/autograde.log"

total_tests=0
total_pass=0
total_fail=0

# Log to screen and file at the same time
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

# ---------------- Project 1: Hello World ----------------
run_tests_for_project01() {
    local student_dir="$1"
    local project_name="project01"
    local project_path="$student_dir/$project_name"
    local student_name
    student_name=$(basename "$student_dir")

    # Skip if student did not submit project01
    if [ ! -d "$project_path" ]; then
        log "SKIP: $student_name has no $project_name"
        return
    fi

    local inputs_file="$TESTS_ROOT/project01/inputs/names.txt"
    local expected_dir="$TESTS_ROOT/project01/expected"

    local image_tag="${student_name}_${project_name}"

    # Build Docker image
    if ! docker build -t "$image_tag" "$project_path" >"project03/build_${student_name}_${project_name}.log" 2>&1; then
        log "BUILD FAIL: $student_name $project_name"
        total_fail=$((total_fail + 1))
        return
    fi

    # Read each name and run container with it as argument
    while read -r name; do
        [ -n "$name" ] || continue

        total_tests=$((total_tests + 1))
        log "---- $student_name | $project_name | $name ----"

        local actual_output="project03/actual_${student_name}_${project_name}_${name}.txt"
        local expected_file="$expected_dir/${name}.txt"

        # Run container: expect "Hello World <name>" on stdout
        if ! timeout 10s docker run --rm "$image_tag" "$name" >"$actual_output" 2>"project03/run_${student_name}_${project_name}.log"; then
            log "RUNTIME FAIL"
            total_fail=$((total_fail + 1))
            continue
        fi

        if diff -q "$actual_output" "$expected_file" >/dev/null 2>&1; then
            log "PASS"
            total_pass=$((total_pass + 1))
        else
            log "FAIL"
            total_fail=$((total_fail + 1))
        fi
    done <"$inputs_file"

    docker rmi "$image_tag" >/dev/null 2>&1 || true
}

# ---------------- Project 2: HTML -> CSV ----------------
run_tests_for_project02() {
    local student_dir="$1"
    local project_name="project02"
    local project_path="$student_dir/$project_name"
    local student_name
    student_name=$(basename "$student_dir")

    # Skip if student did not submit project02
    if [ ! -d "$project_path" ]; then
        log "SKIP: $student_name has no $project_name"
        return
    fi

    local inputs_dir="$TESTS_ROOT/project02/inputs"
    local expected_dir="$TESTS_ROOT/project02/expected"

    local image_tag="${student_name}_${project_name}"

    # Build Docker image
    if ! docker build -t "$image_tag" "$project_path" >"project03/build_${student_name}_${project_name}.log" 2>&1; then
        log "BUILD FAIL: $student_name $project_name"
        total_fail=$((total_fail + 1))
        return
    fi

    # For each HTML test file
    for html_file in "$inputs_dir"/*.html; do
        [ -f "$html_file" ] || continue

        local test_name
        test_name=$(basename "$html_file" .html)
        total_tests=$((total_tests + 1))
        log "---- $student_name | $project_name | $test_name ----"

        local expected_csv="$expected_dir/${test_name}.csv"
        local actual_csv="project03/actual_${student_name}_${project_name}_${test_name}.csv"

        # Run container:
        # - mount inputs at /input
        # - mount project03 at /output
        # - pass /input/<file>.html as argument
        if ! timeout 20s docker run --rm \
            -v "$(pwd)/$inputs_dir":/input \
            -v "$(pwd)/project03":/output \
            "$image_tag" /input/"${test_name}.html" >"project03/run_${student_name}_${project_name}.log" 2>&1; then
            log "RUNTIME FAIL"
            total_fail=$((total_fail + 1))
            continue
        fi

        # Assume student's program writes output.csv in /output
        if [ -f project03/output.csv ]; then
            mv project03/output.csv "$actual_csv"
        else
            log "MISSING OUTPUT CSV"
            total_fail=$((total_fail + 1))
            continue
        fi

        if diff -q "$actual_csv" "$expected_csv" >/dev/null 2>&1; then
            log "PASS"
            total_pass=$((total_pass + 1))
        else
            log "FAIL"
            total_fail=$((total_fail + 1))
        fi
    done

    docker rmi "$image_tag" >/dev/null 2>&1 || true
}

# ---------------- Main driver ----------------
main() {
    : >"$LOG_FILE"

    for student_dir in "$CLASS_ROOT"/*; do
        [ -d "$student_dir" ] || continue

        case "$(basename "$student_dir")" in
            .git|project01|project02|project03|project04|project05|project06|project07|project08|project09|project10|project11|professor_jon_white)
                continue
                ;;
        esac

        local student_name
        student_name=$(basename "$student_dir")

        log "=============================="
        log "Grading student: $student_name"
        log "=============================="

        run_tests_for_project01 "$student_dir"
        run_tests_for_project02 "$student_dir"
    done

    log ""
    log "FINAL SUMMARY"
    log "Total tests: $total_tests"
    log "Passed: $total_pass"
    log "Failed: $total_fail"
}

main "$@"
