#!/bin/bash

FILE=$1

if [ -z "$FILE" ]; then
  FILE="numbers.txt"
fi

echo "========================================"
echo "Prime Counter - Java | Kotlin | Go"
echo "Input File: $FILE"
echo "========================================"
echo

# ---------- JAVA ----------
echo "Compiling Java..."
javac PrimeCounter.java

echo
echo "========== JAVA =========="
java PrimeCounter $FILE
echo

# ---------- KOTLIN ----------
echo "Compiling Kotlin..."
kotlinc PrimeCounter.kt -include-runtime -d PrimeCounter.jar

echo
echo "========== KOTLIN =========="
java -jar PrimeCounter.jar $FILE
echo

# ---------- GO ----------
echo "Compiling Go..."
go build -o prime_counter prime_counter.go

echo
echo "========== GO =========="
./prime_counter $FILE
echo

echo "Done."