# Prime Counter: Java vs Kotlin vs Go (Single-thread vs Multi-thread)

This project reads a text file containing integers (one per line) and counts how many are prime.
It runs the same algorithm in:
- Java
- Kotlin
- Go

Each implementation does:
1. Read and parse all numbers (not timed)
2. Single-threaded prime counting (timed)
3. Multi-threaded prime counting (timed)
4. Prints counts, timings (ms), and speedup

## Prerequisites
- Java JDK (javac + java)
- Kotlin compiler (kotlinc)
- Go (go)

All code uses standard libraries only (no third-party dependencies).

## Directory layout
- java/PrimeCounter.java
- kotlin/PrimeCounter.kt
- golang/prime_counter.go
- run.sh
- tools/generate_numbers.sh

## Generate a test file
```bash
./tools/generate_numbers.sh 1000000 numbers.txt