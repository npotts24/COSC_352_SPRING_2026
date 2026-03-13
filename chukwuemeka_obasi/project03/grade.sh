#!/usr/bin/env bash

set -uo pipefail

# Which projects to check inside each student's directory
PROJECTS=(project01 project02)

# How long to wait for a student's program before giving up
TIMEOUT_SECONDS=10

# Ignore these top-level dirs when looking for student folders
SKIP_DIRS=(tests .git)

# Log file for this run
LOGFILE="grading_$(date +%Y%m%d_%H%M%S).log"

# Helper to write a message to both terminal and log file
log() { echo "$*" | tee -a "$LOGFILE"; }

# Basic checks: do we have Docker and is the daemon available?
if ! command -v docker >/dev/null 2>&1; then
  log "ERROR: docker not found"
  exit 2
fi

if ! docker info >/dev/null 2>&1; then
  log "ERROR: cannot connect to docker daemon"
  exit 2
fi

# counters
pass=0
fail=0
total=0

# keep track of images we build so we can always try to remove them later
declare -a IMAGES_BUILT=()

log "Start $(date)"

# If the script exits for any reason, try to remove images we built
trap 'for img in "${IMAGES_BUILT[@]:-}"; do docker rmi -f "$img" >/dev/null 2>&1 || true; done' EXIT

# iterate student directories: simple immediate children only
IFS=$'\n'
for d in */; do
  s="${d%/}"

  # skip our own test dir and git data
  if [ "$s" = "tests" ] || [ "$s" = ".git" ]; then
    continue
  fi

  echo "Student: $s" | tee -a "$LOGFILE"

  for p in "${PROJECTS[@]}"; do
    proj="$s/$p"
    testsdir="tests/$p"

    # if student doesn't have this project, skip it
    if [ ! -d "$proj" ]; then
      echo "  no $p" | tee -a "$LOGFILE"
      continue
    fi

    # if we don't have tests for the project, note and skip
    if [ ! -d "$testsdir" ]; then
      echo "  no tests for $p" | tee -a "$LOGFILE"
      continue
    fi

    img="${s}_${p}"
    echo "  build $proj" | tee -a "$LOGFILE"

    # try to build the image; if it fails, record and move on
    if ! docker build -t "$img" "$proj" >> "$LOGFILE" 2>&1; then
      echo "  build fail" | tee -a "$LOGFILE"
      continue
    fi

    # remember image so we can clean it up later
    IMAGES_BUILT+=("$img")

    # run each test input file we find
    for t in "$testsdir"/*.in; do
      [ -e "$t" ] || break
      name=$(basename "$t" .in)
      exp="$testsdir/$name.expected"
      out=$(mktemp /tmp/grader_out.XXXXXX)

      echo "    run $name" | tee -a "$LOGFILE"

      # prefer the system `timeout` if present; otherwise run without timeout
      tp=$(command -v timeout 2>/dev/null || true)
      if [[ -n "$tp" && "$tp" != "$PWD/timeout" ]]; then
        "$tp" "$TIMEOUT_SECONDS" bash -c "cat '$t' | docker run --rm -i '$img'" > "$out" 2>>"$LOGFILE" || { echo "    runtime fail" | tee -a "$LOGFILE"; ((fail++)); ((total++)); rm -f "$out"; continue; }
      else
        bash -c "cat '$t' | docker run --rm -i '$img'" > "$out" 2>>"$LOGFILE" || { echo "    runtime fail" | tee -a "$LOGFILE"; ((fail++)); ((total++)); rm -f "$out"; continue; }
      fi

      # compare the student's output with the expected output
      if [[ -f "$exp" ]]; then
        if diff -q "$exp" "$out" >/dev/null 2>&1; then
          echo "    PASS" | tee -a "$LOGFILE"
          ((pass++))
        else
          echo "    FAIL" | tee -a "$LOGFILE"
          diff -u "$exp" "$out" | sed 's/^/      /' | tee -a "$LOGFILE"
          ((fail++))
        fi
      else
        echo "    missing expected: $exp" | tee -a "$LOGFILE"
        ((fail++))
      fi

      ((total++))
      rm -f "$out"
    done

    # try to remove the image we just built for this project
    docker rmi -f "$img" >/dev/null 2>&1 || true
  done
done

echo "Summary: total=$total pass=$pass fail=$fail" | tee -a "$LOGFILE"

exit 0
