#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="bmore-homicide-hist"

echo "Building Docker image"
docker build -t "${IMAGE_NAME}" .

echo "running the container"
docker run --rm -v "$(pwd):/app" "${IMAGE_NAME}"
