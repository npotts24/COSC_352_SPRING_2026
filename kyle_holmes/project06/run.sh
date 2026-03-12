#!/bin/bash

echo "Building Docker image..."
docker build -t homicide-dashboard .

echo "Starting dashboard container..."
docker stop homicide-dashboard 2>/dev/null || true
docker rm homicide-dashboard 2>/dev/null || true

docker run -d \
  --name homicide-dashboard \
  -p 3838:3838 \
  homicide-dashboard

echo "Dashboard running at http://localhost:3838/homicide-dashboard"
