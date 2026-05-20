#!/bin/bash

echo "Building Docker image..."
docker build -t baltimore-homicide .

echo "Running container..."
docker run --rm -v "$(pwd)":/app baltimore-homicide
