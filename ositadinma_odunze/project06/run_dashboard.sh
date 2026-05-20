#!/bin/bash

# Baltimore Homicide Dashboard Runner
# Author: Oc
# Course: COSC 352

set -e

IMAGE_NAME="baltimore-dashboard"
CONTAINER_NAME="baltimore-dashboard-run"
PORT=3838

echo "Baltimore City Police Department"
echo "Homicide Analysis Dashboard"
echo ""

# Stop and remove existing container if running
echo "Cleaning up existing containers..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# Build Docker image
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" .

echo ""
echo "Docker image built successfully!"
echo ""

# Run the container
echo "Starting Shiny server..."
docker run -d \
  --name "$CONTAINER_NAME" \
  -p $PORT:3838 \
  "$IMAGE_NAME"

# Wait for server to start
echo "Waiting for server to initialize..."
sleep 3

echo 
echo "Open your browser and navigate to:"
echo ""
echo "    http://localhost:$PORT"
echo ""
echo "To stop the dashboard, run:"
echo "    docker stop $CONTAINER_NAME"
echo ""
echo "To view logs:"
echo "    docker logs $CONTAINER_NAME"
echo ""
ech