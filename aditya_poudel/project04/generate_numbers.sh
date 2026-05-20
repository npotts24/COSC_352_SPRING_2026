#!/usr/bin/env bash
set -euo pipefail

N="${1:-1000000}"
OUT="${2:-numbers.txt}"

# Generates N integers (some negative/zero), plus a few known primes sprinkled in.
# Uses only standard shell + awk.

echo "Generating $N numbers into $OUT ..."

awk -v n="$N" '
BEGIN {
  srand();

  # A few known primes to ensure some primes exist even if randomness is unlucky
  known_primes[0]=2; known_primes[1]=3; known_primes[2]=5; known_primes[3]=7;
  known_primes[4]=11; known_primes[5]=13; known_primes[6]=17; known_primes[7]=19;
  known_primes[8]=7919; known_primes[9]=104729;

  for (i=1; i<=n; i++) {
    r = rand();

    # ~5% chance: inject a known prime
    if (r < 0.05) {
      idx = int(rand()*10);
      print known_primes[idx];
      continue;
    }

    # Otherwise generate a mix: negatives, zeros, small and large positives
    # Range roughly [-1e9, 1e9]
    sign = (rand() < 0.2) ? -1 : 1;      # ~20% negative
    if (rand() < 0.02) {                 # ~2% zeros
      print 0;
      continue;
    }
    val = int(rand() * 1000000000);
    print sign * val;
  }
}
' > "$OUT"

echo "Done."
echo "Preview:"
head -n 10 "$OUT"