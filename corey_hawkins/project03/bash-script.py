#  Configuration 

STUDENT_PROJECTS_DIR="students"

TEST_CASES_DIR="tests"

LOG_FILE="grading_results.log"

PROJECTS_TO_GRADE=("project01" "project02") # Easily modifiable for future projects

#  Functions 

# Function to log messages to both screen and file

log_message() {

    local message="$1"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"

}

# Function to build a Docker image

build_docker_image() {

    local student_dir="$1"

    local project_name="$2"

    local image_name="${student_dir//\//_}_${project_name}" # Create a unique image name

    log_message "Building Docker image for ${student_dir}/${project_name}..."

    # Navigate to the project directory to build the Dockerfile

    if cd "$student_dir"; then

        if docker build -t "$image_name" . >> "$LOG_FILE" 2>&1; then

            log_message "Successfully built image: $image_name"

            cd - > /dev/null # Return to original directory silently

            echo "$image_name" # Return the image name

        else

            log_message "ERROR: Failed to build image for ${student_dir}/${project_name}. Check $LOG_FILE for details."

            cd - > /dev/null

            return 1 # Indicate failure

        fi

    else

        log_message "ERROR: Could not navigate to directory ${student_dir}."

        return 1

    fi

}

# Function to run a Docker container and capture output

run_and_test_container() {

    local image_name="$1"

    local project_name="$2"

    local student_dir="$3" # Used to construct path to test files

    local test_input_file="$4"

    local expected_output_file="$5"

    log_message "Testing container $image_name with input: $test_input_file"

    # Determines the path to the test files relative to the script's location

    local relative_test_input_path="${TEST_CASES_DIR}/${project_name}/$(basename "$test_input_file")"

    local relative_expected_output_path="${TEST_CASES_DIR}/${project_name}/$(basename "$expected_output_file")"

    # Check if test files exist

    if [ ! -f "$relative_test_input_path" ] || [ ! -f "$relative_expected_output_path" ]; then

        log_message "ERROR: Test input or expected output file not found for ${project_name}. Expected: $relative_test_input_path, $relative_expected_output_path"

        return 1

    fi

    # Constructs the command to run inside the container.

    run_command="cat $container_input_path | your_app_command"

    run_command="your_app_command $container_input_path $container_output_path"

    local actual_output=""

    local container_exit_code=0

    # a temporary file to capture output from the container

    local temp_output_file=$(mktemp)

    log_message "Running container $image_name and executing tests..."

    if docker run --rm -v "$(pwd)/$relative_test_input_path:$container_input_path" \

                 -v "$(pwd)/$temp_output_file:$container_output_path" \

                 "$image_name" \

                 sh -c "your_app_command < $container_input_path > $container_output_path" >> "$LOG_FILE" 2>&1; then

        container_exit_code=$?

        # Copy’s the output from the temporary file inside the container to the host

        if [ -f "$temp_output_file" ]; then

            actual_output=$(cat "$temp_output_file")

        else

            log_message "WARNING: Temporary output file $temp_output_file not found after container run."

        fi

    else

        container_exit_code=$?

        log_message "ERROR: Container execution failed for $image_name. Exit code: $container_exit_code. Check $LOG_FILE."

        # capturedany output that might have been written to stderr or stdout before failure

        actual_output=$(cat "$temp_output_file")

    fi

    # cleans up the temporary file

    rm -f "$temp_output_file"

    # Compares actual output with expected output

    local expected_output=$(cat "$relative_expected_output_path")

    if [ "$container_exit_code" -eq 0 ] && [ "$actual_output" == "$expected_output" ]; then

        log_message "PASS: ${student_dir}/${project_name} - Test case ${test_input_file} passed."

        return 0 # Indicates success

    else

        log_message "FAIL: ${student_dir}/${project_name} - Test case ${test_input_file} failed."

        log_message "  Expected Output: $expected_output"

        log_message "  Actual Output: $actual_output"

        log_message "  Container Exit Code: $container_exit_code"

        return 1 # Indicates failure

    fi

}


# Clears log file at the start of each grading run

> "$LOG_FILE"

log_message " Starting Docker Project Grading "

# sift through each student

find "$STUDENT_PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r student_dir; do

    student_name=$(basename "$student_dir")

    log_message " Grading for Student: $student_name "

    # projects to grade

    for project_name in "${PROJECTS_TO_GRADE[@]}"; do

        local project_path="${student_dir}/${project_name}"

        if [ -d "$project_path" ]; then

            log_message "Processing Project: $project_name for $student_name"

            # Build the Docker image

            local image_name=$(build_docker_image "$project_path" "$project_name")

            if [ $? -ne 0 ]; then

                log_message "Skipping tests for ${student_name}/${project_name} due to build failure."

                continue # Move to the next project

            fi

            # Find test cases for the current project

            local test_inputs=("$TEST_CASES_DIR/$project_name"/input*.txt)

            local all_tests_passed=true

            if [ ${#test_inputs[@]} -eq 0 ] || [ ! -f "${test_inputs[0]}" ]; then

                log_message "WARNING: No test input files found for ${project_name}. Skipping tests."

                all_tests_passed=false # Consider it a failure if no tests can be run

            else

                for test_input_file in "${test_inputs[@]}"; do

                    # Constructs the expected output file name

                    local base_input_name=$(basename "$test_input_file")

                    local expected_output_file="${TEST_CASES_DIR}/${project_name}/${base_input_name/input/expected_output}"

                    if run_and_test_container "$image_name" "$project_name" "$project_path" "$test_input_file" "$expected_output_file"; then

                        : # Test passed, do nothing

                    else

                        all_tests_passed=false # Mark that at least one test failed

                    fi

                done

            fi

            if $all_tests_passed; then

                log_message "Result: PASS - All tests for ${student_name}/${project_name} completed successfully."

            else

                log_message "Result: FAIL - One or more tests failed for ${student_name}/${project_name}."

            fi

            log_message "Removing Docker image: $image_name"

            docker rmi "$image_name" >> "$LOG_FILE" 2>&1

        else

            log_message "Skipping ${project_name} for ${student_name}: Directory not found at ${project_path}"

        fi

    done

done

log_message " Grading Complete "

exit 0

