#!/bin/bash
set -e

echo "Building Docker image..."
docker build --platform=linux/amd64 -t homicide-dashboard .

echo "Removing old container if it exists..."
docker rm -f homicide-dashboard 2>/dev/null || true

echo "Starting dashboard..."
docker run -d --platform=linux/amd64 -p 3838:3838 --name homicide-dashboard homicide-dashboard

echo "Dashboard running at http://localhost:3838"
