#!/bin/bash

INPUT_FILE=$1

if [ -f "$INPUT_FILE" ]; then
    for i in {1..100000}; do echo $(( (RANDOM % 100000) + 1)); done > $INPUT_FILE
fi

#Java Implementation
echo "--JAVA--"
javac java_prime.java
java java_prime $INPUT_FILE

#GO Implementation
echo "--GO--"
go run golang_prime.go $INPUT_FILE

#Kotlin Implementation
echo "--KOTLIN--"
kotlinc kotlin_prime.kt -include-runtime -d kotlin_prime.jar
java -jar kotlin_prime.jar $INPUT_FILE






