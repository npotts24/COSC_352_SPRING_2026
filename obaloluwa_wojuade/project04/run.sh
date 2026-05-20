#!/usr/bin/env bash

INPUT_FILE="${1:-data/numbers.txt}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input file not found: $INPUT_FILE"
  echo "Usage: ./run.sh <input-file>"
  exit 1
fi

for cmd in javac java go kotlinc; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd"
    echo "Please install Java JDK, Kotlin, and Go."
    exit 1
  fi
done

mkdir -p build/java build/kotlin build/go

echo "========================================"
echo "Building Java"
echo "========================================"
if ! javac -d build/java java/PrimeCounter.java; then
  echo "Failed to compile Java"
  exit 1
fi

echo "========================================"
echo "Building Kotlin"
echo "========================================"
if ! kotlinc kotlin/PrimeCounter.kt -include-runtime -d build/kotlin/PrimeCounter.jar; then
  echo "Failed to compile Kotlin"
  exit 1
fi

echo "========================================"
echo "Building Go"
echo "========================================"
if ! go build -o build/go/prime_counter golang/prime_counter.go; then
  echo "Failed to compile Go"
  exit 1
fi

echo
echo "========================================"
echo "Java Result"
echo "========================================"
java -cp build/java PrimeCounter "$INPUT_FILE"

echo
echo "========================================"
echo "Kotlin Result"
echo "========================================"
java -jar build/kotlin/PrimeCounter.jar "$INPUT_FILE"

echo
echo "========================================"
echo "Go Result"
echo "========================================"
./build/go/prime_counter "$INPUT_FILE"

echo "========================================"
echo "Testing complete!"
echo "========================================"