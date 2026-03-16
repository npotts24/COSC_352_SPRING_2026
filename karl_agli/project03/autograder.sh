#!/bin/bash

# Docker Container Autograder
# For grading student Docker projects

# Config - can be modified for different projects
PROJECT_NUM="project01"  # change this for different projects
LOG_FILE="grading_results.log"
STUDENT_DIR="."  # parent directory containing all student folders

# Test cases for project01 (modify this section for other projects)
TEST_INPUT=""
EXPECTED_OUTPUT="Hello World!"

# Initialize counters
total_students=0
passed=0
failed=0

# Function to log output to both terminal and file
log_output() {
  echo "$1" | tee -a "$LOG_FILE"
}

# Function to clean up containers and images
cleanup() {
  local student_name=$1
  local image_name="${student_name}_${PROJECT_NUM}"
  
  # Stop and remove container if it exists
  if docker ps -a | grep -q "$image_name"; then
    docker stop "$image_name" 2>/dev/null
    docker rm "$image_name" 2>/dev/null
  fi
  
  # Remove image if it exists
  if docker images | grep -q "$image_name"; then
    docker rmi "$image_name" 2>/dev/null
  fi
}

# Function to grade a single student
grade_student() {
  local student_path=$1
  local student_name=$(basename "$student_path")
  local project_path="${student_path}/${PROJECT_NUM}"
  
  log_output "\n========================================"
  log_output "Grading: $student_name"
  log_output "========================================"
  
  # Check if project directory exists
  if [ ! -d "$project_path" ]; then
    log_output "[SKIP] Project directory not found: $project_path"
    return
  fi
  
  # Check if Dockerfile exists
  if [ ! -f "${project_path}/Dockerfile" ]; then
    log_output "[SKIP] No Dockerfile found"
    return
  fi
  
  ((total_students++))
  
  local image_name="${student_name}_${PROJECT_NUM}"
  
  # Build the Docker image
  log_output "Building Docker image..."
  if ! docker build -t "$image_name" "$project_path" 2>&1 | tee -a "$LOG_FILE" | grep -q "Successfully built"; then
    log_output "[FAIL] Build failed"
    ((failed++))
    cleanup "$student_name"
    return
  fi
  
  log_output "Running container..."
  
  # Run container and capture output with timeout
  actual_output=$(timeout 10s docker run --rm "$image_name" 2>&1)
  
  if [ $? -eq 124 ]; then
    log_output "[FAIL] Container timed out (exceeded 10s)"
    ((failed++))
    cleanup "$student_name"
    return
  fi
  
  # Compare output
  log_output "Expected: $EXPECTED_OUTPUT"
  log_output "Got: $actual_output"
  
  # Check if output matches (trim whitespace)
  actual_trimmed=$(echo "$actual_output" | xargs)
  expected_trimmed=$(echo "$EXPECTED_OUTPUT" | xargs)
  
  if [ "$actual_trimmed" = "$expected_trimmed" ]; then
    log_output "[PASS] Output matches!"
    ((passed++))
  else
    log_output "[FAIL] Output does not match"
    ((failed++))
  fi
  
  # Cleanup
  cleanup "$student_name"
}

# Main script
main() {
  log_output "=========================================="
  log_output "Docker Container Autograder"
  log_output "Project: $PROJECT_NUM"
  log_output "Started: $(date)"
  log_output "=========================================="
  
  # Clear log file
  > "$LOG_FILE"
  
  # Find all student directories
  for student_dir in "$STUDENT_DIR"/*/ ; do
    # Skip if not a directory
    [ -d "$student_dir" ] || continue
    
    # Get student name from directory
    student_name=$(basename "$student_dir")
    
    # Skip common non-student directories
    if [[ "$student_name" == ".git" ]] || [[ "$student_name" == "README.md" ]]; then
      continue
    fi
    
    grade_student "$student_dir"
  done
  
  # Print summary
  log_output "\n=========================================="
  log_output "GRADING SUMMARY"
  log_output "=========================================="
  log_output "Total Students Graded: $total_students"
  log_output "Passed: $passed"
  log_output "Failed: $failed"
  
  if [ $total_students -gt 0 ]; then
    pass_rate=$((passed * 100 / total_students))
    log_output "Pass Rate: ${pass_rate}%"
  fi
  
  log_output "\nComplete log saved to: $LOG_FILE"
  log_output "Finished: $(date)"
}

# Run the script
main
