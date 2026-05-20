#!/bin/bash

# Project 4: Multithreaded Programming Demonstration
# This script builds and runs all three implementations (Java, Kotlin, Go)

set -e

# Use provided file or default to numbers.txt
INPUT_FILE="${1:-numbers.txt}"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found"
    echo "Usage: ./run.sh [input_file]"
    exit 1
fi

echo "==============================================="
echo "Project 4: Prime Number Counter"
echo "Input file: $INPUT_FILE"
echo "==============================================="
echo ""

# Java
echo "========== JAVA =========="
echo "Compiling Java..."
javac PrimeCounter.java
echo "Running Java implementation..."
java PrimeCounter "$INPUT_FILE"
echo ""

# Kotlin
echo "========== KOTLIN =========="
echo "Compiling Kotlin..."
kotlinc PrimeCounter.kt -include-runtime -d PrimeCounter.jar
echo "Running Kotlin implementation..."
kotlin -classpath PrimeCounter.jar PrimeCounterKt "$INPUT_FILE"
echo ""

# Go
echo "========== GO =========="
echo "Running Go implementation..."
go run prime_counter.go "$INPUT_FILE"
echo ""

echo "==============================================="
echo "All implementations completed successfully!"
echo "==============================================="

