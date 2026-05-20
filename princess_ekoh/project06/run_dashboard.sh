#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="baltimore-homicide-dashboard"
CONTAINER_NAME="baltimore-homicide-dashboard-container"

docker build -t "$IMAGE_NAME" .
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER_NAME" -p 3838:3838 "$IMAGE_NAME"

echo "Dashboard running at http://localhost:3838"
echo "To stop it later, run: docker stop $CONTAINER_NAME"
