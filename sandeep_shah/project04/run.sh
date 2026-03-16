#!/bin/bash

# If no argument provided, use default test file
if [ -z "$1" ]; then
  INPUT_FILE="test_numbers.txt"
else
  INPUT_FILE="$1"
fi

echo "=========================================="
echo " Running Prime Counter Comparison"
echo " Input File: $INPUT_FILE"
echo "=========================================="

# Compile Java
echo ""
echo "----- JAVA -----"
javac java/PrimeCounter.java
if [ $? -ne 0 ]; then
  echo "Java compilation failed."
  exit 1
fi
java -cp java PrimeCounter "$INPUT_FILE"

# Compile Kotlin
echo ""
echo "----- KOTLIN -----"
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar
if [ $? -ne 0 ]; then
  echo "Kotlin compilation failed."
  exit 1
fi
java -jar kotlin/PrimeCounter.jar "$INPUT_FILE"

# Run Go
echo ""
echo "----- GO -----"
go run golang/prime_counter.go "$INPUT_FILE"

echo ""
echo "=========================================="
echo " Finished."
echo "=========================================="
