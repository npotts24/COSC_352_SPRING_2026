#!/usr/bin/env bash
set -e

mkdir -p output

docker build -t homicide-hist .
docker run --rm \
  -v "$(pwd)/output:/app/output" \
  homicide-hist