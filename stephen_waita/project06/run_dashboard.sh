#!/bin/bash

echo "Building Docker image..."

docker build -t homicide_dashboard .

echo "Running dashboard..."

docker run -p 3838:3838 homicide_dashboard

echo "Dashboard running at http://localhost:3838"