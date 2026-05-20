#!/bin/bash
FILE=${1:-"numbers.txt"}

echo "--- Compiling Programs ---"
go build -o go_prime golang/prime_counter.go
javac java/PrimeCounter.java
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin_prime.jar

echo -e "\n--- Running Go Implementation ---"
./go_prime $FILE

echo -e "\n--- Running Java Implementation ---"
java -cp java PrimeCounter $FILE

echo -e "\n--- Running Kotlin Implementation ---"
java -jar kotlin_prime.jar $FILE