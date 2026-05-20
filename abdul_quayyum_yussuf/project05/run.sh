#!/usr/bin/env bash
set -euo pipefail

tag="bmore-histogram:latest"

echo "Building Docker image..."
docker build -t "$tag" .

echo "Running container to produce histogram output:"
# mount current directory into /app so output files are persisted on host
docker run --rm -v "$(pwd)":/app -w /app "$tag"
