#!/bin/bash

COUNT=${1:-1000000}
OUT=${2:-numbers.txt}

shuf -i 1-2000000 -n $COUNT > $OUT
echo "Generated $COUNT numbers in $OUT"