#!/bin/bash

# Baltimore Homicide Data Analysis Runner

set -e

IMAGE_NAME="baltimore-homicide-analysis"
CONTAINER_NAME="baltimore-analysis-run"

echo "Baltimore Homicide Data Analysis"
echo ""

# Build Docker image
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" .

echo ""
echo "Docker image built successfully!"
echo ""

# Remove old container if it exists
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Run the container
echo "Running analysis..."
echo ""
docker run --name "$CONTAINER_NAME" --rm "$IMAGE_NAME"

echo ""
echo "Analysis complete!"