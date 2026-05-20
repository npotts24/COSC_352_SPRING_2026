#!/bin/bash

# run_dashboard.sh - Build and run Baltimore City Homicide Analysis Dashboard
# This script builds the Docker image and runs the Shiny dashboard

set -e  # Exit on error

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_NAME="baltimore-homicide-dashboard"
CONTAINER_NAME="baltimore-dashboard-run-$(date +%s)"

echo "=========================================="
echo "Baltimore City Homicide Analysis Dashboard"
echo "=========================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

echo "[1/2] Building Docker image..."
if ! docker build -t "$IMAGE_NAME" "$PROJECT_DIR"; then
    echo "Error: Failed to build Docker image"
    exit 1
fi

echo ""
echo "[2/2] Starting dashboard..."
echo "Dashboard will be available at: http://localhost:3838"
echo "Press Ctrl+C to stop the dashboard"
echo ""

docker run --rm \
    --name "$CONTAINER_NAME" \
    -p 3838:3838 \
    "$IMAGE_NAME"

echo ""
echo "Dashboard stopped."
echo "=========================================="