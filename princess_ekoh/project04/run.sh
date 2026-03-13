#!/bin/bash
set -e

FILE=${1:-numbers.txt}

echo "================ JAVA ================"
javac java/PrimeCounter.java
java -cp java PrimeCounter "$FILE"

echo ""
echo "================ KOTLIN ================"
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin.jar
java -jar kotlin.jar "$FILE"

echo ""
echo "================ GO ================"
go run golang/prime_counter.go "$FILE"
