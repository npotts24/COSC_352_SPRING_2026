#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="baltimore-homicide-dashboard"
CONTAINER_NAME="baltimore-homicide-dashboard"
PORT=3838

echo "Building Docker image..."
docker build -t ${IMAGE_NAME} .

echo "Stopping any existing container named ${CONTAINER_NAME}..."
docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true

echo "Starting dashboard container (map localhost:${PORT} to container:${PORT})..."
docker run --rm -d --name ${CONTAINER_NAME} -p ${PORT}:3838 ${IMAGE_NAME}

echo "Dashboard running at http://localhost:${PORT}"
