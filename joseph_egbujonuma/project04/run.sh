#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-numbers.txt}"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: Input file not found: $FILE"
  echo "Usage: ./run.sh <path-to-numbers.txt>"
  exit 1
fi

echo "Input file: $FILE"
echo

#----------java build
echo "==================== JAVA ===================="
javac Java/PrimeCounter.java
java -cp Java PrimeCounter "$FILE"
echo

#----------kotlin build
echo "=================== KOTLIN ==================="
if command -v sdk >/dev/null 2>&1; then
  source /usr/local/sdkman/bin/sdkman-init.sh >/dev/null 2>&1 || true
fi

if ! command -v kotlinc >/dev/null 2>&1; then
  echo "ERROR: kotlinc not found."
  echo "In Codespaces, run:"
  echo "  source /usr/local/sdkman/bin/sdkman-init.sh"
  echo "  sdk install kotlin"
  exit 1
fi

kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar
java -jar kotlin/PrimeCounter.jar "$FILE"
echo

#----------GO build
echo "===================== GO ====================="
go run Go/PrimeCounter.go "$FILE"
echo

