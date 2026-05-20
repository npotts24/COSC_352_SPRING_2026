#!/bin/bash

if command -v docker &> /dev/null && [ -f Dockerfile ]; then
    IMAGE_NAME="primecounter"
    if ! docker images | grep -q "$IMAGE_NAME"; then
        echo "Building Docker image..."
        docker build -t "$IMAGE_NAME" .
    fi
    FILE_PATH="${1:-numbers.txt}"
    if [ ! -f "$FILE_PATH" ]; then
        echo "File $FILE_PATH not found."
        exit 1
    fi
    docker run --rm -v "$(pwd)":/app "$IMAGE_NAME" "$FILE_PATH"
else
    FILE_PATH="${1:-numbers.txt}"
    if [ ! -f "$FILE_PATH" ]; then
        echo "File $FILE_PATH not found."
        exit 1
    fi
    echo "Compiling and running directly..."
    # Compile
    javac java/PrimeCounter.java
    kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar
    cd golang && go build prime_counter.go && cd ..
    # Run
    echo "=== Java ==="
    java -cp java:. PrimeCounter "$FILE_PATH"
    echo ""
    echo "=== Kotlin ==="
    java -jar kotlin/PrimeCounter.jar "$FILE_PATH"
    echo ""
    echo "=== Go ==="
    ./golang/prime_counter "$FILE_PATH"
fi