# Docker Grading Automation

This folder contains a Bash-only automated grader for student Docker submissions in:

- `project01`
- `project02`

## Files

- `docker_grader.sh`: Main grading script
- `fixtures/project02_input.html`: Known input for Project 02
- `fixtures/project02_expected.csv`: Expected output for Project 02 validation

## Run

```bash
bash /Users/demiladesojijohn/Desktop/COSC_352_SPRING_2026/grading/docker_grader.sh
```

Optional student filter (regex on folder name):

```bash
bash /Users/demiladesojijohn/Desktop/COSC_352_SPRING_2026/grading/docker_grader.sh 'joseph|jamal'
```

## What The Script Does

1. Scans all top-level student directories automatically.
2. Finds `project01` and `project02` folders.
3. Builds each Docker image from each project folder.
4. Runs tests with `timeout` so one broken submission cannot block grading.
5. Validates outputs:
   - Project 01: output must include `hello` and the known name input.
   - Project 02: output CSV must match the expected CSV fixture.
6. Prints results live and writes them to a log file.
7. Writes a machine-readable summary CSV with scores and pass/fail.
8. Cleans up containers and images after each project.

## Scoring

Each project is scored out of 100 points:

- Project 01:
  - Build: 30
  - Known-input output validation: 50
  - No-input error handling check: 20
- Project 02:
  - Build: 30
  - Run with known input: 20
  - Expected output match: 50

## How To Modify For Future Projects

1. Add new fixture files under `grading/fixtures`.
2. Add a new grading function in `docker_grader.sh` (for example `grade_project03`).
3. Call that function in the main student loop when `project03` exists.
4. Add test weights and validation logic for the new project.
