# Automated Grading Script

Bash script that automatically grades student Docker projects for COSC 352.

## What it does

- Builds each student's Docker container
- Runs test cases with different inputs
- Compares actual output to expected output
- Gives a score and logs everything to a file

## How to use

```bash
# Grade all students for project 01
./grade.sh -p 01

# Grade project 02 for all students
./grade.sh -p 02

# Grade specific student
./grade.sh -p 01 -s john_doe

# Help
./grade.sh -h
```

## Output

Results go to both:
- Your terminal (with colors)
- Log file in `grading_logs/` folder

## Adding new projects

Edit the `define_project_tests()` function in grade.sh:

```bash
case $project in
    03)
        TESTS+=(
            "test_name"
            "input"
            "expected_output"
        )
        ;;
esac
```

## Grading rubric

Starts at 100 points, deductions:
- -30 if it doesn't run/crashes
- -10 for wrong output
- -10 for missing features
- -10 for bad code quality
- -10 for poor design
- -5 for no Dockerfile comments

## Project tests

**Project 01** (Hello World)
- Passes name as argument
- Should output "Hello World [name]"

**Project 02** (HTML Parser)
- File-based project
- Just checks if container runs without crashing

## Troubleshooting

**"No Dockerfile found"**
- Make sure student has a Dockerfile in their project folder

**"Failed to build"**
- Check the log file for build errors

**"Container timed out"**
- Container took too long (default 30 seconds)
- Increase TIMEOUT_SECONDS in the script

**"Permission denied"**
- Run: `chmod +x grade.sh`

## Files

- `grade.sh` - Main grading script
- `grade-utils.sh` - Helper commands (view logs, cleanup, etc.)
- `test-system.sh` - Tests if grading system works
- `README.md` - This file
- `GRADING_CONFIG_TEMPLATE.md` - Examples for adding new projects

## Notes

- Logs include student name when grading specific student
- Docker images are automatically cleaned up after grading
- Script handles errors and continues grading other students

