#!/usr/bin/env bash
# Root directories
PROJECT_DIR="./project02"
# Outputs the grades in a txt file
OUTPUT="result.txt"  
# Input files
TEST_INPUT="project02/parsing.py"
EXPECTED_OUTPUT="project02/parsed.csv"
# Checks all student submissions
echo "Student,Score" > "$OUTPUT"


# Goes through student directories
for student in "$PROJECT_DIR"/*; do
  # If the student exists, print that the assignment is being graded
  if [-f"$student"]; then
    student_name = $(basename "$student")
    echo "Grading $student_name 's assignment. Just a sec..."
    # Put result in temporary file
    TEMP_OUT = "$(mktemp)"
   
   # Copies into temporary file
    bash "$student/regex.sh" < "$TEST_INPUT" > "$TEMP_OUT" 2>/dev/null
    # If the result of the output is equivalent to the one stored in TEMP_OUT, score = 100
    if diff -q "$EXPECTED_OUTPUT" "$TEMP_OUT" > /dev/null 2>&1; then
      score=100
    else
      score=0
    fi
    # Put the name and score of the student in the output file
    echo "$student_name,$score" >> "$OUTPUT"

    rm -f "$TEMP_OUT"
  fi
done
# Output assignment graded
echo "Assignment Graded"


