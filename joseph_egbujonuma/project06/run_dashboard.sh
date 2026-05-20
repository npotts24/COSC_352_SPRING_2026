#!/usr/bin/env bash
set -e

IMAGE_NAME=baltimore-homicide-dashboard

docker build -t "$IMAGE_NAME" .
docker run --rm -p 3838:3838 "$IMAGE_NAME" &

echo "Dashboard running at http://localhost:3838"