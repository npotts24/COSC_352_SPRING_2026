#!/bin/bash

IMAGE_NAME="baltimore-dashboard"

echo "Building Docker image..."
docker build -t $IMAGE_NAME .

echo "Running container..."
docker run -p 3838:3838 $IMAGE_NAME

echo "Dashboard running at http://localhost:3838"