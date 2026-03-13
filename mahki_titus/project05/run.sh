#!/bin/bash

echo "Building Docker image..."

docker build -t baltimore-homicide .

# Stop if build fails
if [ $? -ne 0 ]; then
    echo "Docker build failed."
    exit 1
fi

echo "Running analysis..."

docker run --rm baltimore-homicide