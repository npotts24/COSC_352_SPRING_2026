# Docker Grading Automation

This folder contains a Bash-only automated grader for:

- `project01` (Docker required by assignment)
- `project02` (Dockerfile not required)

## Files

- `docker_grader.sh`: Main grading script
- `fixtures/project02_input.html`: Frozen full HTML snapshot of the programming languages page

## Run (Yes, just run the Bash script)

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
   - Project 02: grader runs submitted source scripts directly (no student Dockerfile required), then validates output with a rubric against the full-page fixture:
     - minimum CSV data-row volume
     - required header coverage (`Language`, `Original purpose`, paradigm columns, etc.)
     - known language coverage (Ada, Python, Java, Rust, etc.)
     - header-row presence
     - anti-raw-HTML guard (`<table>/<tr>/<td>` markers should not dominate output)
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
  - Run with known input: 40
  - Rubric-based output validation: 60

## Project 02 Accuracy Note

Project 02 now uses a realistic, static webpage snapshot instead of a tiny synthetic table.
This makes grading more accurate for the actual assignment objective (extracting real webpage tables into CSV) while still remaining deterministic.

## How To Modify For Future Projects

1. Add new fixture files under `grading/fixtures`.
2. Add a new grading function in `docker_grader.sh` (for example `grade_project03`).
3. Call that function in the main student loop when `project03` exists.
4. Add test weights and validation logic for the new project.
