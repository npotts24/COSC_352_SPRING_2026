import random
import sys

n = int(sys.argv[1]) if len(sys.argv) > 1 else 1000000
output = sys.argv[2] if len(sys.argv) > 2 else 'numbers.txt'

with open(output, 'w') as f:
    for _ in range(n):
        # Mix of positive, negative, zero, and large primes
        r = random.random()
        if r < 0.05:
            f.write('0\n')
        elif r < 0.10:
            f.write(f'{random.randint(-1000, -1)}\n')
        else:
            f.write(f'{random.randint(2, 1500000)}\n')

print(f'Generated {n} numbers in {output}')
