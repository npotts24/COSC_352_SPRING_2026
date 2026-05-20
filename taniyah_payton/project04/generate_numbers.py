#!/usr/bin/env python3
"""Generate a test file with random integers for prime counting benchmarks."""
import random
import sys

count = int(sys.argv[1]) if len(sys.argv) > 1 else 1_000_000
out_file = sys.argv[2] if len(sys.argv) > 2 else "numbers.txt"

with open(out_file, "w") as f:
    for _ in range(count):
        # Mix of small and large numbers, plus some negatives and zeros
        r = random.random()
        if r < 0.05:
            f.write(f"{random.randint(-1000, 1)}\n")
        elif r < 0.3:
            f.write(f"{random.randint(2, 1000)}\n")
        else:
            f.write(f"{random.randint(2, 10_000_000)}\n")

print(f"Generated {count:,} numbers -> {out_file}")
