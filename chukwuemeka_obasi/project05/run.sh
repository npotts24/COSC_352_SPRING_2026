#!/bin/bash

docker build -t homicide-project .
docker run --rm homicide-project