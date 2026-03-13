#!/bin/bash

FILE=${1:-numbers.txt}

echo "===== JAVA ====="
javac java/PrimeCounter.java
java -cp java PrimeCounter $FILE

echo -e "\n===== KOTLIN ====="
./kotlinc/bin/kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin.jar
java -jar kotlin.jar $FILE

echo -e "\n===== GO ====="
go run golang/prime_counter.go $FILE