#!/bin/bash

# Friendly banner
echo "======================================="
echo "    Project 05: Homicide Analysis"
echo "======================================="
echo

# Step 1: Build Docker image
echo "Step 1: Building Docker image..."
docker build -t project05-homicide-analysis .

if [ $? -ne 0 ]; then
    echo "❌ Docker build failed. Please check your Dockerfile and try again."
    exit 1
fi
echo "✅ Docker image built successfully!"
echo

# Step 2: Run Docker container with folder mapping
echo "Step 2: Running analysis inside Docker container..."
docker run --rm -v "$PWD":/app project05-homicide-analysis

if [ $? -ne 0 ]; then
    echo "❌ Analysis failed. Check the R script for errors."
    exit 1
fi
echo
echo "🎉 Analysis completed successfully!"
echo "Your histogram (histogram.png) should now be in this folder:"
echo "$PWD"
echo
echo "You can open it with:"
echo "open histogram.png"
echo "======================================="
