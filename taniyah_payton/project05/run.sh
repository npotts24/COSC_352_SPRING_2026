#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="baltimore-homicides"
CONTAINER_NAME="baltimore-run"
OUTPUT_DIR="$(pwd)/output"

echo "========================================"
echo "  Baltimore Homicide Histogram Builder  "
echo "========================================"

# Build the Docker image
echo ""
echo ">>> Building Docker image '${IMAGE_NAME}' ..."
docker build -t "${IMAGE_NAME}" .

# Create a local output directory
mkdir -p "${OUTPUT_DIR}"

# Remove any leftover container
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Run the container
echo ""
echo ">>> Running analysis (this may take a minute on first run) ..."
echo ""
docker run \
  --name "${CONTAINER_NAME}" \
  --rm \
  -v "${OUTPUT_DIR}:/output" \
  "${IMAGE_NAME}"

echo ""
echo ">>> Done!  Histogram PNG saved to: ${OUTPUT_DIR}/histogram.png"
