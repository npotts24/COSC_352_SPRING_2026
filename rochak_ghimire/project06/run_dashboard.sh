#!/bin/bash

echo "Stopping any existing container..."
docker stop homicide-dashboard 2>/dev/null || true
docker rm homicide-dashboard 2>/dev/null || true

echo "Building Docker image (this may take several minutes first time)..."
docker build -t homicide-dashboard .

if [ $? -ne 0 ]; then
  echo "❌ Docker build failed. Check the output above."
  exit 1
fi

echo "Running container..."
docker run -d --name homicide-dashboard -p 3838:3838 homicide-dashboard

echo ""
echo "✅ Dashboard running at http://localhost:3838"
echo "   Wait ~15 seconds for Shiny to start, then open your browser."
echo ""
echo "To stop: docker stop homicide-dashboard"
