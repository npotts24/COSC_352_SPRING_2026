#!/bin/bash
#configuration
STUDENT_DIR = "./submissions"
TEST_DIR = "./tests"
LOG_FILE = "grading.log"

TOTAL_PASS=0
TOTAL_FAIL=0

echo "Starting grading..." | tee "$LOG_FILE"
echo "-----------------------------------" | tee -a "$LOG_FILE"
#function
run_test () {
    local student=$1
    local image=$2
    local input_file=$3
    local expected_file=$4

    output=$(cat "$input_file" | timeout 10 docker run --rm "$image" 2>/dev/null)
    diff <(echo "$output") "$expected_file" >/dev/null
    if [$? -eq 0]; then
        echo "PASS" | tee -a "$LOG_FILE"
        return 0
    else
        echo "FAIL" | tee -a "$LOG_FILE"
        echo "Expected:" | tee -a "$LOG_FILE"
        cat "$expected_file" | tee -a "$LOG_FILE"
        echo "Got:" | tee -a "$LOG_FILE"
        echo "$output" | tee -a "$LOG_FILE"
        return 1
        fi
}
#main loop
for student_path in "$STUDENT_DIR"/*; do
    student = $(basename "$student_path")
    image_name = "project_${student}"

    echo "" | tee -a "$LOG_FILE"
    echo "Grading $student" | tee -a "$LOG_FILE"
    cd "$student_path" || continue

    #build docker image
    docker build -t "$image_name" . > /dev/null 2>&1
    if [$? -ne 0]; then
        echo "Build failed for $student" | tee -a "$LOG_FILE"
        TOTAL_FAIL = $((TOTAL_FAIL+1))
        cd - > /dev/null
        continue
    fi

    student_pass=0
    student_fail=0

    #run all tests
    for input in "$TEST_DIR"/input*; do
        test_name = $(basename "$input")
        expected = "$TEST_DIR/expected_${test_name#input}"

        echo -n "Test $test_name: " | tee -a "$LOG_FILE"
        run_test "$student" "$image_name" "$input" "$expected"

        if [$? -eq 0]; then
            student_pass = $((student_pass+1))
        else
            student_fail = $((student_fail+1))
        fi
    done
    echo "$student results: PASS = $student_pass FAIL = $student_fail" | tee -a "$LOG_FILE"

    TOTAL_PASS = $((TOTAL_PASS+student_pass))
    TOTAL_FAIL = $((TOTAL_FAIL+student_fail))

    #cleanup
    docker rmi "$image_name" > /dev/null 2>&1
    cd - > /dev/null
done
echo "FINAL SUMMARY" | tee -a "$LOG_FILE"
echo "Total Passed Tests: $TOTAL_PASS" | tee -a "$LOG_FILE"
echo "Total Failed Tests: $TOTAL_FAIL" | tee -a "$LOG_FILE"