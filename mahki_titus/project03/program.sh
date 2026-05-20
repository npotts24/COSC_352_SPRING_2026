#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Need two numbers"
    exit 1
fi

echo $(($1 + $2))
