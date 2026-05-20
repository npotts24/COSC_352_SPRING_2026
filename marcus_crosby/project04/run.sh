#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="${1:-$SCRIPT_DIR/sample_numbers.txt}"
THREAD_COUNT="${2:-}"

JAVA_FILE="$SCRIPT_DIR/Primecountbench.java"
KOTLIN_FILE="$SCRIPT_DIR/Primecountbench.kt"
GO_FILE="$SCRIPT_DIR/primecountbench.go"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input file not found: $INPUT_FILE"
  echo "Usage: ./build.sh [input-file] [thread-count]"
  exit 1
fi

run_section() {
  echo
  echo "=============================="
  echo "$1"
  echo "=============================="
}

PROGRAM_ARGS=("$INPUT_FILE")
if [[ -n "$THREAD_COUNT" ]]; then
  PROGRAM_ARGS+=("$THREAD_COUNT")
fi

run_section "Java"
if command -v javac >/dev/null 2>&1 && command -v java >/dev/null 2>&1; then
  if javac "$JAVA_FILE"; then
    java -cp "$SCRIPT_DIR" Primecountbench "${PROGRAM_ARGS[@]}"
  else
    echo "Java compile failed."
  fi
else
  echo "Skipping Java: javac/java not found."
fi

run_section "Kotlin"
if command -v kotlinc >/dev/null 2>&1 && command -v java >/dev/null 2>&1; then
  if kotlinc "$KOTLIN_FILE" -include-runtime -d "$SCRIPT_DIR/Primecountbench.jar"; then
    java -jar "$SCRIPT_DIR/Primecountbench.jar" "${PROGRAM_ARGS[@]}"
  else
    echo "Kotlin compile failed."
  fi
else
  echo "Skipping Kotlin: kotlinc and/or java not found."
fi

run_section "Go"
if command -v go >/dev/null 2>&1; then
  if go build -o "$SCRIPT_DIR/primecountbench-go" "$GO_FILE"; then
    "$SCRIPT_DIR/primecountbench-go" "${PROGRAM_ARGS[@]}"
  else
    echo "Go build failed."
  fi
else
  echo "Skipping Go: go not found."
fi
