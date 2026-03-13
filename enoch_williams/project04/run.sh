#!/usr/bin/env bash
set -euo pipefail

# Wrapper script to run the repository-level runner using the repository numbers.txt
# Usage: ./run.sh [path-to-numbers.txt]

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FILE="${1:-$ROOT/numbers.txt}"

echo "Using input file: $FILE"
cd "$ROOT"
exec ./run.sh "$FILE"
#!/usr/bin/env bash
set -euo pipefail

FILE=${1:-numbers.txt}

echo "Using input file: $FILE"

echo "\nCompiling Kotlin..."
if ! command -v kotlinc >/dev/null 2>&1; then
  echo "kotlinc not found; please install Kotlin compiler to run Kotlin program."
else
  kotlinc Primes.kt -include-runtime -d Primes.jar
fi

echo "Compiling Java..."
javac Primes.java

echo "Building Go..."
if ! command -v go >/dev/null 2>&1; then
  echo "go not found; please install Go to run Go program."
else
  go build -o primes_go primes.go
fi

echo "\n--- Running Go ---"
if [ -x ./primes_go ]; then
  ./primes_go "$FILE"
else
  echo "Skipping Go (binary missing)"
fi

echo "\n--- Running Kotlin ---"
if [ -f Primes.jar ]; then
  java -jar Primes.jar "$FILE"
else
  echo "Skipping Kotlin (Primes.jar missing)"
fi

echo "\n--- Running Java ---"
if [ -f Primes.class ]; then
  java Primes "$FILE"
else
  echo "Skipping Java (Primes.class missing)"
fi
enoch_williams/project05