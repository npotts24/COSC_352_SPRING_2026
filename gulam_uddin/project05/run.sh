#!/bin/bash

# Baltimore Homicide Analysis Runner
# This script builds the Docker image and runs the analysis

set -e  # Exit on error

echo "======================================"
echo "Baltimore Homicide Data Analysis"
echo "======================================"
echo ""

# Build the Docker image
echo "Building Docker image..."
docker build -t baltimore-homicide-analysis .

echo ""
echo "Running analysis..."
echo ""

# Run the container
docker run --rm baltimore-homicide-analysis

echo ""
echo "Analysis complete!"
