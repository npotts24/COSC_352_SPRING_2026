#!/bin/bash

# run.sh - Build and run Baltimore City Homicide Data Analysis
# This script builds the Docker image and runs the container

set -e  # Exit on error

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_NAME="baltimore-homicide-analysis"
CONTAINER_NAME="baltimore-homicide-run-$(date +%s)"

echo "=========================================="
echo "Baltimore City Homicide Data Analysis"
echo "=========================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

echo "[1/3] Building Docker image..."
docker build -t "$IMAGE_NAME" "$PROJECT_DIR"

echo ""
echo "[2/3] Running container..."
docker run --rm \
    --name "$CONTAINER_NAME" \
    -v "$PROJECT_DIR:/output" \
    "$IMAGE_NAME"

echo ""
echo "[3/3] Done!"
echo ""

# Check if histogram.png was created
if [ -f "$PROJECT_DIR/histogram.png" ]; then
    echo "✓ Histogram image saved to: $PROJECT_DIR/histogram.png"
fi

echo "=========================================="
echo "Analysis Complete"
echo "=========================================="
