#!/usr/bin/env bash

set -uo pipefail

PROJECTS=(project01 project02)

TIMEOUT_SECONDS=10

SKIP_DIRS=(tests .git)

LOGFILE="grading_$(date +%Y%m%d_%H%M%S).log"

log() { echo "$*" | tee -a "$LOGFILE"; }

if ! command -v docker >/dev/null 2>&1; then
  log "ERROR: docker not found"
  exit 2
fi

pass=0
fail=0
total=0

log "Start $(date)"

for d in */; do
  s=${d%/}
  if [ "$s" = "tests" ] || [ "$s" = ".git" ]; then
    continue
  fi
  echo "Student: $s" | tee -a "$LOGFILE"

  for p in "${PROJECTS[@]}"; do
    proj="$s/$p"
    testsdir="tests/$p"
    if [ ! -d "$proj" ]; then
      echo "  no $p" | tee -a "$LOGFILE"
      continue
    fi
    if [ ! -d "$testsdir" ]; then
      echo "  no tests for $p" | tee -a "$LOGFILE"
      continue
    fi

    img="${s}_${p}"
    echo "  build $proj" | tee -a "$LOGFILE"
    if ! docker build -t "$img" "$proj" >> "$LOGFILE" 2>&1; then
      echo "  build fail" | tee -a "$LOGFILE"
      continue
    fi

    for t in "$testsdir"/*.in; do
      [ -e "$t" ] || break
      name=$(basename "$t" .in)
      exp="$testsdir/$name.expected"
      out="/tmp/out.$$"
      echo "    run $name" | tee -a "$LOGFILE"
      tp=$(command -v timeout 2>/dev/null || true)
      if [[ -n "$tp" && "$tp" != "$PWD/timeout" ]]; then
        timeout 10 bash -c "cat '$t' | docker run --rm -i '$img'" > "$out" 2>>"$LOGFILE" || { echo "    runtime fail" | tee -a "$LOGFILE"; ((fail++)); ((total++)); continue; }
      else
        bash -c "cat '$t' | docker run --rm -i '$img'" > "$out" 2>>"$LOGFILE" || { echo "    runtime fail" | tee -a "$LOGFILE"; ((fail++)); ((total++)); continue; }
      fi
      if diff -q "$exp" "$out" >/dev/null 2>&1; then
        echo "    PASS" | tee -a "$LOGFILE"
        ((pass++))
      else
        echo "    FAIL" | tee -a "$LOGFILE"
        diff -u "$exp" "$out" | sed 's/^/      /' | tee -a "$LOGFILE"
        ((fail++))
      fi
      ((total++))
      rm -f "$out"
    done

    docker rmi -f "$img" >/dev/null 2>&1 || true
  done
done

echo "Summary: total=$total pass=$pass fail=$fail" | tee -a "$LOGFILE"

exit 0
