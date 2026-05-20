# Project 04 — Prime Counter (Java, Kotlin, Go)

This project implements a prime-counting program in three languages: Java, Kotlin and Go. Each implementation provides a single-threaded and a multi-threaded version, times both runs (computation only), and prints the prime count and elapsed time.

Files
- `java/PrimeCounter.java` — Java implementation (uses `ExecutorService`)
- `kotlin/PrimeCounter.kt` — Kotlin implementation (JVM, uses `ExecutorService`)
- `golang/prime_counter.go` — Go implementation (goroutines + channels)
- `run.sh` — Builds and runs all three programs with the same input file.
- `numbers.txt` — Small sample input.
- `generate_numbers.py` — Optional generator for larger test sets.

Build & Run
Make sure `javac`, `java`, `kotlinc`, `kotlinc` runtime, `go`, and `python3` are available.

Run the full suite:
```
./run.sh numbers.txt
```

Generate a large test file (optional):
```
python3 generate_numbers.py big.txt 1000000 1000000
```

Design notes
- Primality uses trial division and checks 6k ± 1 after small primes (2 and 3).
- File I/O reads and parses all numbers before timing begins to keep I/O out of measurements.
- The multi-threaded versions split the input into contiguous chunks; number of threads defaults to number of CPU cores.

Constraints
- Only standard libraries are used.
