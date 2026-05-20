#!/usr/bin/env bash
set -euo pipefail

COUNT="${1:-100000}"
OUT="${2:-numbers.txt}"

awk -v n="$COUNT" 'BEGIN{
  srand();
  primes[1]=2; primes[2]=3; primes[3]=5; primes[4]=7;
  primes[5]=11; primes[6]=7919; primes[7]=104729; primes[8]=999983;

  for(i=1;i<=n;i++){
    r = rand();
    if(i % 10000 == 0){
      pidx = 1 + int(rand()*8);
      print primes[pidx];
    } else if(r < 0.05){
      print 0;
    } else if(r < 0.10){
      print 1;
    } else if(r < 0.20){
      print -1 * int(rand()*1000000);
    } else {
      print int(rand()*2000000000);
    }
  }
}' > "$OUT"

echo "Wrote $COUNT numbers to $OUT"
