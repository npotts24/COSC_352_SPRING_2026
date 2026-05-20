#!/bin/bash
# run.sh - build and run Docker container for histogram project

set -euo pipefail

docker build -t baltimore-histogram .

echo "Running container..."
docker run --rm baltimore-histogram
