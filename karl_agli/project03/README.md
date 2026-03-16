# Project 3 - Docker Container Autograder

Bash script that automatically grades student Docker container projects. Builds each student's container, runs tests, and generates a grading report.

## How It Works

1. Loops through all student directories
2. For each student:
   - Checks if project folder and Dockerfile exist
   - Builds the Docker image
   - Runs the container and captures output
   - Compares output to expected results
   - Cleans up containers/images
3. Generates summary with pass/fail stats

## Usage

### Basic Usage

Run from the parent directory containing all student folders:

```bash
chmod +x autograder.sh
./autograder.sh
```

### Configuration

Edit these variables at the top of the script:

- `PROJECT_NUM` - which project to grade (project01, project02, etc.)
- `EXPECTED_OUTPUT` - what the correct output should be
- `TEST_INPUT` - input data to send to container (if needed)
- `LOG_FILE` - where to save the grading log

### Example for Different Projects

**For project01:**
```bash
PROJECT_NUM="project01"
EXPECTED_OUTPUT="Hello World!"
```

**For project02:**
```bash
PROJECT_NUM="project02"
EXPECTED_OUTPUT="<expected output here>"
```

## Requirements

- Bash shell
- Docker installed and running
- Student directories structured as: `student_name/project01/Dockerfile`

## Output

The script outputs results to:
- Terminal (real-time)
- Log file (grading_results.log)

Example output:
```
==========================================
Grading: john_doe
==========================================
Building Docker image...
Running container...
Expected: Hello World!
Got: Hello World!
[PASS] Output matches!
```

## Features

- Automatic iteration through student directories
- Real-time output and logging
- Error handling (build failures, timeouts)
- Container cleanup after each test
- Final summary with statistics
- Easy to modify for different projects

## Error Handling

- Skips students without Dockerfile
- Handles build failures
- 10 second timeout on container execution
- Cleans up even if errors occur

## Notes

Make sure Docker is running before executing the script. The script will skip any student directories that don't have the required project folder or Dockerfile.
