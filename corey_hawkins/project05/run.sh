# !/bin/bash

# defines image name and exits immediately if a non-zero status exists

set -e

IMAGE_NAME="homicide-histogram-app"

CONTAINER_NAME="homicide-app-runner"

echo " Building Docker image: $IMAGE_NAME "

# building the Docker image

docker build -t $IMAGE_NAME .

echo ""

echo " Running Docker container: $CONTAINER_NAME "

# runs the Docker container, while —rm allows interactive terminal and attaches STDOUT/STDER

docker run --rm --name $CONTAINER_NAME $IMAGE_NAME

echo ""

echo " Script execution finished "
