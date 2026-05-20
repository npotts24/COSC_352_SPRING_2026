#!/bin/bash

echo "Building Docker image..."
docker build -t baltimore-homicide .

echo "Running analysis..."
docker run --rm baltimore-homicide