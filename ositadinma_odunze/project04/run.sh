#!/bin/bash



set -e

# Default test file
INPUT_FILE="${1:-numbers.txt}"


# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found"
    echo "Usage: ./run.sh [input_file]"
    echo "If no file is provided, 'numbers.txt' will be used"
    exit 1
fi

echo "Input file: $INPUT_FILE"
echo ""

# Java
echo "Compiling Java..."
javac java/PrimeCounter.java

echo "Running Java..."
java -cp java PrimeCounter "$INPUT_FILE"
echo ""

# Kotlin
echo "Compiling Kotlin..."
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar

echo "Running Kotlin..."
java -jar kotlin/PrimeCounter.jar "$INPUT_FILE"
echo ""

# Go
echo "Compiling Go..."
go build -o golang/prime_counter golang/prime_counter.go

echo "Running Go..."
./golang/prime_counter "$INPUT_FILE"
