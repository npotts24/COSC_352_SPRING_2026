#!/bin/bash

# Baltimore City Homicide Data Analysis - Docker Runner
# This script builds and runs the Docker container

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_NAME="baltimore-homicide-analysis"
IMAGE_NAME="$PROJECT_NAME:latest"

echo "======================================"
echo "Baltimore Homicide Data Analysis"
echo "======================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "[ERROR] Docker is not installed. Please install Docker first."
    exit 1
fi

echo "[*] Building Docker image: $IMAGE_NAME"
cd "$SCRIPT_DIR"
docker build -t "$IMAGE_NAME" .

if [ $? -ne 0 ]; then
    echo "[ERROR] Docker build failed."
    exit 1
fi

echo ""
echo "[*] Running container..."
echo "======================================"
echo ""

# Run the container and display output
docker run --rm "$IMAGE_NAME"

RESULT=$?

echo ""
echo "======================================"
if [ $RESULT -eq 0 ]; then
    echo "[OK] Analysis completed successfully"
else
    echo "[ERROR] Analysis failed with exit code $RESULT"
fi
echo "======================================"

exit $RESULT
