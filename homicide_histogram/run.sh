#!/usr/bin/env bash
set -e

docker build -t homicide-hist .
docker run --rm homicide-hist
