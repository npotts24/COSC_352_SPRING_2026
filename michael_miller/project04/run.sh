#!/usr/bin/env bash
set -e

FILE="${1:-numbers.txt}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$FILE" ]; then
  echo "Usage: ./run.sh <numbers_file>"
  echo "File not found: $FILE"
  exit 1
fi

ABS_FILE="$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")"

echo "=========================================="
echo " Project 4 - Multithreaded Prime Counter"
echo " Input: $FILE"
echo "=========================================="

# ----- Java -----
echo ""
echo "--- Java ---"
javac "$SCRIPT_DIR/java/PrimeCounter.java" -d "$SCRIPT_DIR/java"
java -cp "$SCRIPT_DIR/java" PrimeCounter "$ABS_FILE"

# ----- Kotlin -----
echo ""
echo "--- Kotlin ---"
kotlinc "$SCRIPT_DIR/kotlin/PrimeCounter.kt" -include-runtime -d "$SCRIPT_DIR/kotlin/PrimeCounter.jar" 2>/dev/null
java -jar "$SCRIPT_DIR/kotlin/PrimeCounter.jar" "$ABS_FILE"

# ----- Go -----
echo ""
echo "--- Go ---"
go build -o "$SCRIPT_DIR/golang/prime_counter" "$SCRIPT_DIR/golang/prime_counter.go"
"$SCRIPT_DIR/golang/prime_counter" "$ABS_FILE"

echo ""
echo "=========================================="
echo " Done!"
echo "=========================================="
