#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="oluwasegun-project05-r"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
docker run --rm "$IMAGE_NAME"
