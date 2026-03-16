#!/bin/bash

echo "Building Docker image..."

docker build -t homicide-dashboard .

echo "Starting dashboard..."

docker run -p 3838:3838 homicide-dashboard

echo "Dashboard running at http://localhost:3838"