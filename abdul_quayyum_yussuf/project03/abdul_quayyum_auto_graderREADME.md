# Docker Container Grader for CS Projects

An automated grading system for validating student Docker container implementations of COSC 352 projects.

## Overview

`abdul_quayyum_auto_grader.sh` is a Bash grader script that:
- Builds Docker images from each student's project Dockerfile
- Runs tests against those containers using stdin, command-line args, or HTTP calls
- Compares actual output to expected output (with support for flexible matching)
- Logs all results to a timestamped file in `abdul_quayyum_yussuf/project03/grading_results/`
- Displays real-time results to the console

## Quick Start

```bash
cd /workspaces/COSC_352_SPRING_2026
bash abdul_quayyum_auto_grader.sh
```

Results will be printed to console and logged to `abdul_quayyum_yussuf/project03/grading_results/grading_YYYYMMDD_HHMMSS.log`

## Test Files

Test cases are defined in `abdul_quayyum_yussuf/project03/grading_tests/` with one file per project:
- `project01.tests` — Tests for Project 01
- `project02.tests` — Tests for Project 02

### Test File Format

Each line in a `.tests` file defines one test case (pipe-delimited):
```
test_type|run_args|input|expected_output|mode
```

**Fields:**
- `test_type` — `stdin`, `args`, or `http`
  - `stdin` — Pass input via stdin; run_args are optional additional command
  - `args` — Pass run_args as command-line arguments; input field unused
  - `http` — Run container as web service; run_args is container port; input is "GET /path"
- `run_args` — Arguments to pass; for http tests, the container port (e.g., `80`)
- `input` — Input data (for stdin tests) or HTTP method/path (for http tests)
- `expected_output` — Expected output to match
- `mode` (optional) — Matching mode: `exact` (default) or `contains`
  - `exact` — Output must match expected string exactly
  - `contains` — Output must contain the expected string

### Example Test Cases

**Project 01: Hello World with Command-Line Args**
```
args|Alice||Alice|contains
args|Bob||Bob|contains
```
Tests that passing "Alice" and "Bob" as arguments produces output containing those names.

**Project 02: HTML Table to CSV**
```
args|/tmp/test_table.html||CSV|contains
```
Tests that passing an HTML file produces output containing "CSV" (indicating file creation).

## Grading Results

Output files are stored in: `/workspaces/COSC_352_SPRING_2026/abdul_quayyum_yussuf/project03/grading_results/`

Example log output:
```
[INFO] Starting grading run. Logfile: /workspaces/COSC_352_SPRING_2026/abdul_quayyum_yussuf/project03/grading_results/grading_20260212_202810.log
[INFO] Building image grader_abdul_quayyum_yussuf_project01 from abdul_quayyum_yussuf/project01
[PASS] abdul_quayyum_yussuf/project01: test (args Alice) PASSED
[PASS] abdul_quayyum_yussuf/project01: test (args Bob) PASSED
[INFO] abdul_quayyum_yussuf/project01: 2/2 tests passed
[INFO] Grading run complete
```

## Project Requirements

### Project 01: Hello World Docker Container
- Python program that accepts a name via command-line argument
- Outputs text containing the name
- Dockerized application

### Project 02: HTML Table to CSV Parser
- Python program that reads HTML files (local or URL)
- Parses tables from HTML using only standard library
- Outputs table data to CSV file(s)
- Program signature: `python read_html_table.py <URL|FILENAME>`

## Customization

### Modifying Tests

Edit the `.tests` files in `abdul_quayyum_yussuf/project03/grading_tests/` to add, remove, or change test cases.

### Adding New Projects

1. Create test file: `abdul_quayyum_yussuf/project03/grading_tests/projectNN.tests`
2. Update `abdul_quayyum_auto_grader.sh` line with `PROJECTS=` to include `projectNN`
3. Add any special handling if needed in the `run_testcase()` function

### Flexible Matching

Use `contains` mode in the 5th field of test definitions for flexible output matching:
```
args|test_arg||expected_substring|contains
```

This is useful when student implementations have variations in output format but contain the required data.

## Tips for Writing Tests

- **Minimal:** Write tests that validate core functionality, not formatting
- **Flexible:** Use `contains` mode when exact output format varies
- **Clear Comments:** Add comments in `.tests` files explaining what each test validates
- **Real Input:** For projects that read files, include realistic test HTML/data
- **Error Handling:** Tests should handle both success and error cases gracefully

## Troubleshooting

**"no Dockerfile" skipped:**
- Ensure the student's project directory has a Dockerfile

**Test fails despite correct output:**
- Check for whitespace/newline differences (use `contains` mode if exact match isn't critical)
- Verify the test expectation matches what the student actually implemented
- Run the container manually to debug: `docker run --rm -v /path/to/file:/path/to/file image_name args`

**CSV file not found (Project 02):**
- Verify the Dockerfile copies the Python script correctly
- Ensure the ENTRYPOINT is set to run the script
- Check that the script writes to the working directory in the container

## Architecture

The grader follows this flow:

1. **Setup:** Ensure test directory and test files exist; create default tests if needed
2. **Discovery:** Iterate through student directories for each project
3. **Build:** Docker build student's Dockerfile; tag with grader label
4. **Test:** Load tests from `.tests` file; for each test:
   - Set up test data (e.g., create HTML file for Project 02)
   - Run container with appropriate input/args
   - Capture output
   - Normalize output (trim whitespace, etc.)
   - Compare against expected (exact or substring match)
5. **Report:** Log results and print to console with [PASS]/[FAIL] labels
6. **Cleanup:** Remove built images to save space

## Advanced Features

- **Real-time logging:** Output tee'd to both console and log file
- **Flexible test types:** stdin, args, http; easily extensible
- **Result summary:** Per-student/project pass rate displayed
- **Volume mounting:** HTML/data files can be mounted into containers for testing
- **Automatic test population:** Default tests created if none exist
