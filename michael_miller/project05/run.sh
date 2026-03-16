#!/usr/bin/env bash
set -e

IMAGE_NAME="baltimore-homicide-histogram"

echo "=== Building Docker image ==="
docker build -t "$IMAGE_NAME" .

echo ""
echo "=== Running analysis ==="
docker run --rm "$IMAGE_NAME"
