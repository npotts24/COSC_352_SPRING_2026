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

echo "Compiling Java..."
javac java/PrimeCounter.java

echo "Compiling Kotlin..."
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar

echo "Compiling Go..."
go build -o golang/prime_counter golang/prime_counter.go

echo
echo "========== JAVA =========="
java -cp java PrimeCounter $FILE

echo
echo "========== KOTLIN =========="
java -jar kotlin/PrimeCounter.jar $FILE

echo
echo "========== GO =========="
./golang/prime_counter $FILE

echo
echo "Done."