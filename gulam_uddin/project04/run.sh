#!/bin/bash

FILE=${1:-testdata/numbers.txt}

echo "======================================"
echo " PROJECT 04 - PRIME COUNTER"
echo "======================================"
echo "Input File: $FILE"
echo

# -------- Compile Programs --------

echo "Compiling Java..."
javac java/PrimeCounter.java

echo "Compiling Kotlin..."
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/prime.jar

echo "Building Go..."
go build -o golang/prime golang/prime_counter.go

echo
echo "======================================"
echo "JAVA OUTPUT"
echo "======================================"
java -cp java PrimeCounter $FILE

echo
echo "======================================"
echo "KOTLIN OUTPUT"
echo "======================================"
java -jar kotlin/prime.jar $FILE

echo
echo "======================================"
echo "GO OUTPUT"
echo "======================================"
./golang/prime $FILE
