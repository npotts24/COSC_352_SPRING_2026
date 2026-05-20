#!/bin/bash
set -u

# ---------------- Config
SUBMISSIONS_DIR="./submissions"
TESTS_DIR="./tests"
LOG_FILE="grades.log"
IMAGE_NAME="student_app"
TIMEOUT_SECONDS=10   


echo "Grading Session: $(date)" > "$LOG_FILE"
echo "-----------------------------------" | tee -a "$LOG_FILE"

# ---------------- Checks if test exists
if [ ! -d "$TESTS_DIR" ]; then
  echo "[FATAL] Missing tests directory: $TESTS_DIR" | tee -a "$LOG_FILE"
  exit 1
fi

inputs=( "$TESTS_DIR"/input*.txt )
if [ "${#inputs[@]}" -eq 1 ] && [ ! -f "${inputs[0]}" ]; then
  echo "[FATAL] No test inputs found. Expected files like: $TESTS_DIR/input1.txt" | tee -a "$LOG_FILE"
  exit 1
fi

# ----------------Grading
for student_dir in "$SUBMISSIONS_DIR"/*; do
  [ -d "$student_dir" ] || continue

  student_name=$(basename "$student_dir")
  echo -e "\nGrading: $student_name" | tee -a "$LOG_FILE"


  if [ ! -f "$student_dir/Dockerfile" ]; then
    echo "Result: BUILD FAILED (Missing Dockerfile)" | tee -a "$LOG_FILE"
    echo "-----------------------------------" | tee -a "$LOG_FILE"
    continue
  fi

  #----------------Building the container
  echo "Building $student_name..." | tee -a "$LOG_FILE"
  docker build -t "$IMAGE_NAME:$student_name" "$student_dir" >> "$LOG_FILE" 2>&1
  if [ $? -ne 0 ]; then
    echo "Result: BUILD FAILED" | tee -a "$LOG_FILE"
    echo "-----------------------------------" | tee -a "$LOG_FILE"
    continue
  fi


  total=0
  passed=0

  for input_file in "$TESTS_DIR"/input*.txt; do
    [ -f "$input_file" ] || continue
    total=$((total + 1))

    suffix="${input_file#"$TESTS_DIR"/input}"   # e.g. "1.txt"
    expected_file="$TESTS_DIR/expected$suffix"  # e.g. "expected1.txt"

    echo "Test $total: $(basename "$input_file")" | tee -a "$LOG_FILE"

    if [ ! -f "$expected_file" ]; then
      echo "  FAIL (missing expected file: $(basename "$expected_file"))" | tee -a "$LOG_FILE"
      continue
    fi

    expected_output="$(cat "$expected_file")"

    
    actual_output="$(
      timeout "$TIMEOUT_SECONDS" docker run --rm -i "$IMAGE_NAME:$student_name" < "$input_file" 2>> "$LOG_FILE"
    )"
    run_rc=$?

    if [ $run_rc -eq 124 ]; then
      echo "  FAIL (timeout after ${TIMEOUT_SECONDS}s)" | tee -a "$LOG_FILE"
      continue
    elif [ $run_rc -ne 0 ]; then
      echo "  FAIL (runtime error, exit code $run_rc)" | tee -a "$LOG_FILE"
      echo "  Expected: $expected_output" >> "$LOG_FILE"
      echo "  Actual: $actual_output" >> "$LOG_FILE"
      continue
    fi

    if [ "$actual_output" = "$expected_output" ]; then
      echo "  PASS" | tee -a "$LOG_FILE"
      passed=$((passed + 1))
    else
      echo "  FAIL (wrong output)" | tee -a "$LOG_FILE"
      echo "  Expected: $expected_output" >> "$LOG_FILE"
      echo "  Actual: $actual_output" >> "$LOG_FILE"
    fi
  done

  #------------------------------Scoring the assignmet 
  if [ "$total" -eq 0 ]; then
    score=0
  else
    score=$(( passed * 100 / total ))
  fi

  echo "Summary: $passed/$total tests passed -> Score: $score" | tee -a "$LOG_FILE"

  # Cleanup
  docker rmi "$IMAGE_NAME:$student_name" >/dev/null 2>&1 || true

  echo "-----------------------------------" | tee -a "$LOG_FILE"
done
