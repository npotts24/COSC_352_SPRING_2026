#!/bin/bash
docker build --no-cache -t baltimore-homicide .
docker run --rm baltimore-homicide