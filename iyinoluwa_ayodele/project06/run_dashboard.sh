#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

docker rm -f baltimore-dashboard 2>/dev/null || true

echo "Building dashboard image..."
docker build -t baltimore-dashboard .

echo "Starting dashboard container..."
docker run -d --name baltimore-dashboard -p 3838:3838 baltimore-dashboard

echo "Dashboard running at http://localhost:3838"
