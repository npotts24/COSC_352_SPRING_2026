#!/bin/bash
# run_dashboard.sh
# Builds and runs the BPD Homicide Analysis Shiny Dashboard

set -e

IMAGE_NAME="bpd-homicide-dashboard"
PORT=3838

echo "Building Docker image: $IMAGE_NAME ..."
docker build -t $IMAGE_NAME .

echo "Starting container on port $PORT ..."
docker run --rm -p ${PORT}:3838 $IMAGE_NAME &

echo ""
echo "Dashboard running at http://localhost:${PORT}"
echo "Press Ctrl+C to stop the container."
