#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="cosc352-project06-homicide-dashboard"
CONTAINER_NAME="cosc352-project06-homicide-dashboard"
PORT="3838"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[1/3] Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
  echo "[2/3] Removing old container: $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null
else
  echo "[2/3] No existing container to remove"
fi

echo "[3/3] Starting dashboard container on port $PORT"
docker run -d --name "$CONTAINER_NAME" -p "$PORT:3838" "$IMAGE_NAME" >/dev/null

# Give shiny-server a moment to initialize and fail fast if startup crashes.
sleep 4

if ! docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
  echo "Dashboard container failed to stay running. Recent logs:"
  docker logs --tail 120 "$CONTAINER_NAME" || true
  exit 1
fi

echo "Dashboard running at http://localhost:$PORT"
echo "To stop it: docker rm -f $CONTAINER_NAME"
