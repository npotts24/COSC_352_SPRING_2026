#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: ./run.sh <input_file>"
  exit 1
fi

FILE=$1

echo "Compiling Java..."
javac java/PrimeCounter.java

echo "Compiling Kotlin..."
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar

echo "Compiling Go..."
cd golang
go build prime_counter.go
cd ..

echo "=================================="
echo "JAVA"
echo "=================================="
java -cp java PrimeCounter $FILE

echo "=================================="
echo "KOTLIN"
echo "=================================="
java -jar kotlin/PrimeCounter.jar $FILE

echo "=================================="
echo "GO"
echo "=================================="
./golang/prime_counter $FILE
