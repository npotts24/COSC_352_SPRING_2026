#!/bin/bash

docker build -t homicide_analysis .

docker run --rm -v $(pwd):/output homicide_analysis
