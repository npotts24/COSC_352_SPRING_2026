#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="cosc352-project05-homicide"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[1/2] Building Docker image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

echo "[2/2] Running histogram script in container"
docker run --rm -v "$SCRIPT_DIR:/app" "$IMAGE_NAME"
