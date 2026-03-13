#!/bin/bash

set -e

echo "Building Docker image..."
docker build -t bmore-homicide-analysis .

echo "Running Analysis..."
docker run --rm bmore-homicide-analysis