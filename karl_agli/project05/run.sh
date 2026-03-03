#!/usr/bin/env bash
# run.sh - Project 5: Baltimore Homicide Data Analysis
# Usage: ./run.sh
# Builds the Docker image, runs the container, and prints the histogram
# output to the terminal.

set -e

IMAGE_NAME="baltimore-homicide-histogram"
CONTAINER_NAME="baltimore-homicide-run"

echo "=================================================="
echo " Baltimore City Homicide Data Analysis"
echo " Project 5 - COSC 352"
echo "=================================================="
echo ""

# 1. Build the Docker image
echo "[1/2] Building Docker image: ${IMAGE_NAME} ..."
docker build -t "${IMAGE_NAME}" .
echo "Build complete."
echo ""

# 2. Run the container and capture / print output
echo "[2/2] Running container ..."
echo ""
docker run --rm --name "${CONTAINER_NAME}" "${IMAGE_NAME}"

echo ""
echo "Done. Histogram PNG saved inside the container (homicides_by_month.png)."
echo "To copy the PNG to your local machine run:"
echo "  docker run --rm -v \$(pwd):/output ${IMAGE_NAME} cp homicides_by_month.png /output/"
