#!/bin/bash

echo "Building Docker image..."
docker build -t baltimore-homicide-dashboard .

echo "Running dashboard..."

docker run -p 3838:3838 baltimore-homicide-dashboard

echo "Dashboard running at http://localhost:3838"