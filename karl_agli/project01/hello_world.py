#!/usr/bin/env python3
import sys

if len(sys.argv) < 2:
    print("Hello World User")
else:
    name = sys.argv[1]
    print(f"Hello World {name}")
