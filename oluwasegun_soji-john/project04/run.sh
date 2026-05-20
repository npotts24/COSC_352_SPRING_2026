#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="${1:-$SCRIPT_DIR/numbers.txt}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: input file not found -> $INPUT_FILE" >&2
  echo "Usage: ./run.sh [path_to_numbers_file]" >&2
  exit 1
fi

require_cmd() {
  local cmd="$1"
  local help="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required. $help" >&2
    exit 1
  fi
}

require_cmd javac "Install a JDK to compile Java."
require_cmd java "Install a JRE/JDK to run Java/Kotlin artifacts."
require_cmd kotlinc "Install Kotlin compiler."
require_cmd go "Install Go toolchain."

echo "========================================"
echo "Prime Counter Benchmark Runner"
echo "Input file: $INPUT_FILE"
echo "========================================"
echo

echo "========== Java =========="
javac "$SCRIPT_DIR/java/PrimeCounter.java"
java -cp "$SCRIPT_DIR/java" PrimeCounter "$INPUT_FILE"
echo

echo "========== Kotlin =========="
kotlinc "$SCRIPT_DIR/kotlin/PrimeCounter.kt" -include-runtime -d "$SCRIPT_DIR/kotlin/prime_counter.jar"
java -jar "$SCRIPT_DIR/kotlin/prime_counter.jar" "$INPUT_FILE"
echo

echo "========== Go =========="
GOCACHE_DIR="${GOCACHE:-$SCRIPT_DIR/.gocache}"
mkdir -p "$GOCACHE_DIR"
GOCACHE="$GOCACHE_DIR" go build -o "$SCRIPT_DIR/golang/prime_counter_bin" "$SCRIPT_DIR/golang/prime_counter.go"
"$SCRIPT_DIR/golang/prime_counter_bin" "$INPUT_FILE"
echo
