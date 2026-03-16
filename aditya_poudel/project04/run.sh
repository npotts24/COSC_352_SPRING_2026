#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-numbers.txt}"

echo "============================================================"
echo "Prime Counter Benchmark (Java vs Kotlin vs Go)"
echo "Input: $INPUT_FILE"
echo "============================================================"
echo

# Check tools
command -v javac >/dev/null 2>&1 || { echo "Error: javac not found."; exit 1; }
command -v java  >/dev/null 2>&1 || { echo "Error: java not found."; exit 1; }
command -v kotlinc >/dev/null 2>&1 || { echo "Error: kotlinc not found."; exit 1; }
command -v go >/dev/null 2>&1 || { echo "Error: go not found."; exit 1; }

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: input file not found: $INPUT_FILE"
  exit 1
fi

echo "---- Building Java ----"
javac PrimeCounter.java
echo "Java build OK"
echo

echo "---- Building Kotlin ----"
kotlinc PrimeCounter.kt -include-runtime -d PrimeCounter.jar
echo "Kotlin build OK"
echo

echo "---- Building Go ----"
go build -o prime_counter prime_counter.go
echo "Go build OK"
echo

echo "=============================="
echo "RUN: Java"
echo "=============================="
java PrimeCounter "$INPUT_FILE"
echo

echo "=============================="
echo "RUN: Kotlin"
echo "=============================="
java -jar PrimeCounter.jar "$INPUT_FILE"
echo

echo "=============================="
echo "RUN: Go"
echo "=============================="
./prime_counter "$INPUT_FILE"
echo