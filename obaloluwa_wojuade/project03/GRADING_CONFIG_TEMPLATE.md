#!/bin/bash

################################################################################
# Grading Configuration Template
# 
# Use this file as a reference for adding new projects
# Copy the examples and modify for your specific project requirements
################################################################################

################################################################################
# PROJECT 01 CONFIGURATION
# Type: Command-Line Argument Based
# Runs program with arguments and compares stdout
################################################################################

# Test Case Format:
# TESTS+=(
#     "descriptive_test_name"    # Name for logging
#     "input_value"              # What to pass to the program
#     "expected_output_string"   # What stdout should contain
# )

PROJECT_01_TESTS=(
    # Test 1: Basic name
    "greeting_alice"
    "Alice"
    "Hello World Alice"
    
    # Test 2: Different name
    "greeting_bob"
    "Bob"
    "Hello World Bob"
    
    # Test 3: Name with spaces
    "greeting_long_name"
    "John Doe"
    "Hello World John Doe"
)

################################################################################
# PROJECT 02 CONFIGURATION
# Type: File-Based Processing
# Container parses input files and generates output files
################################################################################

# For file-based projects, test input is "FILE_BASED"
# and expected output can be "auto" (just check it runs)
# or a specific file path to compare

PROJECT_02_TESTS=(
    # Test 1: HTML to CSV conversion
    "html_to_csv_conversion"
    "FILE_BASED"
    "auto"  # Just verify it runs successfully
)

################################################################################
# EXAMPLE: PROJECT 03 - FIBONACCI SEQUENCE
# Type: Stdin and Stdout
################################################################################

PROJECT_03_TESTS_EXAMPLE=(
    # Test 1: Generate first 5 fibonacci numbers
    "fibonacci_count_5"
    "5"
    "0 1 1 2 3"
    
    # Test 2: Generate first 10 fibonacci numbers
    "fibonacci_count_10"
    "10"
    "0 1 1 2 3 5 8 13 21 34"
    
    # Test 3: Edge case
    "fibonacci_count_1"
    "1"
    "0"
)

################################################################################
# EXAMPLE: PROJECT 04 - HTTP SERVER
# Type: Network-Based (requires nc or curl)
################################################################################

PROJECT_04_TESTS_EXAMPLE=(
    # Test 1: GET request
    "http_get_root"
    "GET / HTTP/1.1"
    "200 OK"
    
    # Test 2: GET /api  
    "http_get_api"
    "GET /api HTTP/1.1"
    "200 OK"
    
    # Test 3: POST request
    "http_post_data"
    "POST /data HTTP/1.1"
    "201 Created"
)

################################################################################
# EXAMPLE: PROJECT 05 - DATABASE OPERATIONS
# Type: Complex File Operations
################################################################################

PROJECT_05_TESTS_EXAMPLE=(
    # Test 1: Insert record
    "db_insert_user"
    "INSERT:john,25,engineer"
    "Record inserted successfully"
    
    # Test 2: Query records
    "db_query_users"
    "SELECT:age>20"
    "john,25,engineer"
    
    # Test 3: Delete record
    "db_delete_user"
    "DELETE:john"
    "Record deleted"
)

################################################################################
# EXAMPLE: PROJECT 06 - JSON API CLIENT
# Type: JSON Input/Output with curl
################################################################################

PROJECT_06_TESTS_EXAMPLE=(
    # Test 1: Parse JSON response
    "json_parse_data"
    '{"name":"Alice","age":30}'
    "Alice,30"
    
    # Test 2: Validate JSON structure
    "json_validate"
    '{"user":{"id":1,"email":"alice@example.com"}}'
    "alice@example.com"
)

################################################################################
# EXAMPLE: PROJECT 07 - LOG FILE ANALYZER
# Type: File Input with String Processing
################################################################################

PROJECT_07_TESTS_EXAMPLE=(
    # Test 1: Count error lines
    "logs_count_errors"
    "errors.log"
    "42"
    
    # Test 2: Filter by timestamp
    "logs_filter_time"
    "2026-02-13"
    "15"
)

################################################################################
# RUBRIC DEDUCTION GUIDE
# Adjust these values in grade.sh based on project requirements
################################################################################

# Standard deduction values:
# DEDUCT_NON_FUNCTIONAL=30        Critical: Program doesn't run at all
# DEDUCT_MISSING_FEATURES=10      Requirement not met
# DEDUCT_POOR_READABILITY=10      Bad variable names, no comments
# DEDUCT_POOR_DESIGN=10           Not modular, hardcoded values
# DEDUCT_VALIDATION_FAILURE=10    Wrong output (divided by test count)
# DEDUCT_ERROR_HANDLING=10        No error checking
# DEDUCT_DISALLOWED_TOOLS=30      Uses forbidden languages/tools

# Example: Strict grading for Project 01
# DEDUCT_NON_FUNCTIONAL=25
# DEDUCT_MISSING_FEATURES=15
# DEDUCT_POOR_READABILITY=15
# DEDUCT_POOR_DESIGN=15

# Example: Lenient grading for Project 02 (complex task)
# DEDUCT_NON_FUNCTIONAL=20
# DEDUCT_MISSING_FEATURES=5
# DEDUCT_POOR_READABILITY=5
# DEDUCT_POOR_DESIGN=5

################################################################################
# INPUT/OUTPUT TYPES REFERENCE
################################################################################

# TYPE 1: COMMAND-LINE ARGUMENTS
# ================================
# Method: Pass data as program arguments
# Container: docker run --rm image_name ARG1 ARG2 ...
# Example: ./hello-world.py Alice
# Use for: Programs that take CLI arguments
#
# Test definition:
# TESTS+=("test1" "Alice" "Hello World Alice")

# TYPE 2: STDIN INPUT
# ===================
# Method: Pipe data into stdin
# Container: echo "DATA" | docker run --rm -i image_name
# Example: echo "5" | ./fibonacci.py
# Use for: Interactive programs, calculators, filters
#
# Test definition:
# TESTS+=("test1" "5" "0 1 1 2 3")

# TYPE 3: FILE-BASED
# ==================
# Method: Container processes files in working directory
# Container: docker run --rm image_name
# Example: Container reads input.txt, produces output.txt
# Use for: Batch processing, conversions, transformations
#
# Test definition:
# TESTS+=("test1" "FILE_BASED" "auto")

# TYPE 4: NETWORK-BASED
# =====================
# Method: Container runs server, test sends HTTP/TCP requests
# Container: docker run --rm -p 8080:8080 image_name
# Container Test: curl localhost:8080 or nc localhost 8080
# Use for: Web servers, APIs, networked services
#
# Requires: Additional docker run flags and network setup

# TYPE 5: ENVIRONMENT VARIABLES
# ==============================
# Method: Pass environment variables to container
# Container: docker run --rm -e VAR=value image_name
# Example: docker run --rm -e NAME=Alice image_name
# Use for: Configuration-based programs
#
# Test definition:
# Modify run_container_test() to include -e flags

################################################################################
# HOW TO ADD A NEW PROJECT
################################################################################

# Step 1: Add project case in define_project_tests() function
#
# case 03)
#     # Project 03: Description of project
#     TESTS+=(
#         "test1" "input1" "expected1"
#     )
#     TESTS+=(
#         "test2" "input2" "expected2"
#     )
#     ;;

# Step 2: Determine input/output method
#   - What data does the program accept? (args, stdin, files, HTTP)
#   - How does it produce output? (stdout, files, HTTP response)

# Step 3: Define test cases
#   - Create 3-5 representative test cases
#   - Include edge cases
#   - Include failure scenarios if applicable

# Step 4: Implement input method in run_container_test()
#   - Update the case statement if new input type needed
#   - Handle stdin redirection for interactive programs
#   - Handle port mapping for network services

# Step 5: Test with one student
#   ./grade.sh -p 03 -s test_student_name

# Step 6: Review output and logs
#   - Check if tests fail as expected
#   - Verify pass/fail logic
#   - Adjust test cases if needed

# Step 7: Run full grading
#   ./grade.sh -p 03

################################################################################
# ADVANCED FEATURES
################################################################################

# Custom return codes:
# Programs can use different exit codes
# 0 = success, non-zero = failure
# Grade.sh checks return code for functional requirement

# Partial credit:
# Modify score calculation in grade_student_project()
# Instead of binary pass/fail, award partial points
# Example: score=$((score - 5))  for minor issues

# Performance requirements:
# Adjust TIMEOUT_SECONDS per project
# Modify run_container_test() to validate execution time
# Example: Compare real time vs expected time

# Output tolerance:
# Modify compare_output() for fuzzy matching
# Useful for floating-point results, timestamps
# Example: Allow ±10% difference for numeric output

# Multiple test files:
# For projects using different input files
# Create test data directory with test files
# Mount as volume or copy into container

################################################################################
# DOCKER CONTAINER REQUIREMENTS
################################################################################

# Every student project must have:
# 1. Dockerfile in project directory
# 2. ENTRYPOINT or CMD that executes the program
# 3. All necessary source files COPY'd in Dockerfile
# 4. Required dependencies installed

# Example Dockerfile structure:
# FROM python:3.11-slim
# WORKDIR /app
# COPY . .
# RUN pip install -r requirements.txt
# ENTRYPOINT ["python", "main.py"]

# Good practices:
# - Use official base images
# - Minimize layer count
# - Set proper WORKDIR
# - Make sure program runs from ENTRYPOINT
# - Clean up package manager cache

################################################################################
# NOTES
################################################################################

# - All test inputs/outputs are strings
# - Whitespace is trimmed automatically in compare_output()
# - Case-sensitive comparisons
# - Docker images are removed after each test
# - Containers run with --rm (auto-cleanup)
# - 30 second timeout per container run
# - Failed builds skip all tests for that student
# - Errors are logged but don't stop grading other students

