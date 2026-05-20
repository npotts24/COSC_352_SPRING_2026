#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFILE="${1:-$ROOT_DIR/numbers.txt}"

echo "Using input: $INFILE"
echo

echo "=== Java ==="
mkdir -p "$ROOT_DIR/java/bin"
javac "$ROOT_DIR/java/PrimeCounter.java" -d "$ROOT_DIR/java/bin"
java -cp "$ROOT_DIR/java/bin" PrimeCounter "$INFILE"

echo
echo "=== Kotlin ==="
kotlinc "$ROOT_DIR/kotlin/PrimeCounter.kt" -include-runtime -d "$ROOT_DIR/kotlin/PrimeCounter.jar"
java -jar "$ROOT_DIR/kotlin/PrimeCounter.jar" "$INFILE"

echo
echo "=== Go ==="
go build -o "$ROOT_DIR/golang/prime_counter" "$ROOT_DIR/golang/prime_counter.go"
"$ROOT_DIR/golang/prime_counter" "$INFILE"

echo
echo "Done."
