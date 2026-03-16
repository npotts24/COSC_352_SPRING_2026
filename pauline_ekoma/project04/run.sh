#!/bin/bash

FILE="numbers.txt"

echo "---- JAVA ----"
javac java/primeCount.java
java -cp java primeCount $FILE

echo "---- KOTLIN ----"
kotlinc kotlin/primeCount.kt -include-runtime -d kotlin/prime.jar
java -jar kotlin/prime.jar $FILE

echo "---- GOLANG ----"
go run golang/primeCount.go $FILE