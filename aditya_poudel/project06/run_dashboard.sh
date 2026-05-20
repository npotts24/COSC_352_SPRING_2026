#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="baltimore-homicide-dashboard"
CONTAINER_NAME="baltimore-dashboard"
HOST_PORT=3838

echo "=============================================="
echo "  Baltimore Homicide Dashboard — Build & Run"
echo "=============================================="

# Remove any old container with the same name
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "Stopping and removing existing container: ${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

echo ""
echo "Step 1/2: Building Docker image (this may take several minutes on first run)..."
docker build -t "${IMAGE_NAME}" .

echo ""
echo "Step 2/2: Starting Shiny Server container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_PORT}:3838" \
  "${IMAGE_NAME}"

echo ""
echo "=============================================="
echo "  Dashboard is starting up..."
echo "  Open your browser at:"
echo ""
echo "    http://localhost:${HOST_PORT}"
echo ""
echo "  (Allow ~10 seconds for the app to load data on first visit)"
echo "=============================================="
echo ""
echo "To stop the dashboard:  docker rm -f ${CONTAINER_NAME}"
echo "To view logs:           docker logs -f ${CONTAINER_NAME}"