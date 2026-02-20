#!/bin/bash

#URL to class Repository
REPO_URL="https://github.com/professor-jon-white/COSC_352_SPRING_2026"
#Name of the folder where the repo is downloaded
TEMP_DIR="class_submissions"
#File where all grading logs will be stored
LOG_FILE="grading_results.log"

#Project 1 check - Python program that prints "Hello World <name>"
TEST_NAME=""
PROJECT01_EXPECTED="Hello World $TEST_NAME"

#Project 2 check - CSV file of programming languages from Wikipedia table
read -r -d '' PROJECT02_EXPECTED << 'EOF' || true
Language,First appeared,Typing,Paradigm
Python,1991,Dynamic,Multi-paradigm
Java,1995,Static,Object-oriented
C,1972,Static,Procedural
JavaScript,1995,Dynamic,Multi-paradigm
C++,1985,Static,Multi-paradigm
C#,2000,Static,Object-oriented
Ruby,1995,Dynamic,Object-oriented
PHP,1995,Dynamic,Multi-paradigm
Swift,2014,Static,Multi-paradigm
Go,2009,Static,Compiled
EOF


#The expected output of the project (will be set per project in the loop)
EXPECTED_OUTPUT=""

#deletes the old folder so start clean every time
rm -rf "$TEMP_DIR"
#Clear out the log file so results from the previous students are not shown
> "$LOG_FILE"
#Download the repo
git clone "$REPO_URL" "$TEMP_DIR"

#Counters to keep track of final score
PASS_COUNT=0
FAIL_COUNT=0


for student_dir in "$TEMP_DIR"/*/; do
    [ -d "$student_dir" ]

    student_name=$(basename "$student_dir")
    
    # Check only project01 and project02
    for proj in project01 project02; do
        proj_dir="$student_dir/$proj"
        [ -d "$proj_dir" ] || continue
        
        # Set expected output based on project
        if [ "$proj" = "project01" ]; then
            EXPECTED_OUTPUT="$PROJECT01_EXPECTED"
        else
            EXPECTED_OUTPUT="$PROJECT02_EXPECTED"
        fi
        
        echo "Grading Student: $student_name - $proj" | tee -a "$LOG_FILE" 

        #Build the docker image
        docker build -t "test_${student_name}_${proj}" "$proj_dir" >> "$LOG_FILE" 2>&1

        #Comparison
        if [ $? -eq 0 ]; then
            # Pass TEST_NAME as argument to the docker container
            actual_output=$(docker run --rm "test_${student_name}_${proj}" "$TEST_NAME" | xargs)

            if [ "$actual_output" == "$EXPECTED_OUTPUT" ]; then
                echo "Result: PASS" | tee -a "$LOG_FILE"
                ((PASS_COUNT++)) #Add to the pass counter
            else
                echo "Result: Fail (Got: $actual_output)" | tee -a "$LOG_FILE"
                ((FAIL_COUNT++)) #Add to the fail counter
            fi

            #Delete the built docker image
            docker rmi "test_${student_name}_${proj}" > /dev/null 2>&1

        else
            echo "Result: Docker build failed" | tee -a "$LOG_FILE"
            ((FAIL_COUNT++))
        fi
    done
done

#Display final results
echo "GRADING DONE" | tee -a "$LOG_FILE"
echo "TOTAL PASSED: $PASS_COUNT" | tee -a "$LOG_FILE"
echo "TOTAL FAILED: $FAIL_COUNT" | tee -a "$LOG_FILE"

