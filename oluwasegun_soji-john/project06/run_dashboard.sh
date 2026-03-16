#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="oluwasegun-project06-dashboard"
CONTAINER_NAME="oluwasegun-project06-dashboard"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
docker run -d --rm --name "$CONTAINER_NAME" -p 3838:3838 "$IMAGE_NAME" >/dev/null
echo "Dashboard running at http://localhost:3838"
echo "Stop it with: docker stop $CONTAINER_NAME"
