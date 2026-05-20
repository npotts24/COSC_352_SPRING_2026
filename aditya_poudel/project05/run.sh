#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="bmore-homicide-hist"

echo "==> Building Docker image: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" .

echo
echo "==> Running container (mounting current directory so histogram.png is saved here)"
docker run --rm -v "$(pwd):/work" "${IMAGE_NAME}"