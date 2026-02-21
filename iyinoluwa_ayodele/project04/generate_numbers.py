#!/usr/bin/env python3
"""
Simple generator for test data.
Usage: python3 generate_numbers.py out.txt count max
Generates `count` integers in range [0, max].
"""
import random
import sys

def main():
    if len(sys.argv) < 4:
        print("Usage: generate_numbers.py out.txt count max")
        return
    out = sys.argv[1]
    count = int(sys.argv[2])
    mx = int(sys.argv[3])
    with open(out, 'w') as f:
        for _ in range(count):
            f.write(str(random.randint(0, mx)) + "\n")
    print(f"Wrote {count} numbers to {out}")

if __name__ == '__main__':
    main()
