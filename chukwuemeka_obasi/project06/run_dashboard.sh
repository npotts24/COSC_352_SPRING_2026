#!/bin/bash

# Define name
IMAGE_NAME="homicide-dashboard"

echo "Step 1: Cleaning up old containers..."
docker stop $(docker ps -q --filter ancestor=$IMAGE_NAME) 2>/dev/null

echo "Step 2: Building image (this will take a few minutes)..."
docker build -t $IMAGE_NAME .

echo "Step 3: Starting dashboard at http://localhost:3838"
docker run -p 3838:3838 $IMAGE_NAME