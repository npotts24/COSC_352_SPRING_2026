#!/bin/bash

# Define image name
IMAGE_NAME="bpd-homicide-dashboard"

echo "Building Docker image..."
docker build -t $IMAGE_NAME .

echo "Stopping existing containers..."
docker stop $IMAGE_NAME || true
docker rm $IMAGE_NAME || true

echo "Starting dashboard on http://localhost:3838"
docker run -d -p 3838:3838 --name $IMAGE_NAME $IMAGE_NAME

echo "----------------------------------------------------"
echo "Project 6 is live! Access it at: http://localhost:3838"
echo "----------------------------------------------------"