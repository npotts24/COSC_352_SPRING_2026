# Project 4 - Multithreaded Prime Counter

Implements a prime-counting program in **Java**, **Kotlin**, and **Go**, each using both single-threaded and multi-threaded approaches.

## Prerequisites

| Tool | Version |
|------|---------|
| Java JDK | 11+ |
| Kotlin | 1.8+ (`kotlinc`) |
| Go | 1.18+ |

No Docker required. No third-party libraries used.

## How to Run

```bash
./run.sh numbers.txt
```

This will compile and run all three programs against the given input file.

### Generate Test Data

```bash
python3 generate_numbers.py        # creates numbers.txt with 1,000,000 entries
./run.sh numbers.txt
```

## File Structure

```
project04/
  java/PrimeCounter.java     - Java implementation
  kotlin/PrimeCounter.kt     - Kotlin implementation
  golang/prime_counter.go    - Go implementation
  run.sh                     - Build and run script
  generate_numbers.py        - Test data generator
  numbers.txt                - Sample test data
  README.md                  - This file
```

## Design Decisions

### Primality Algorithm
All three programs use the same efficient trial-division algorithm: after checking divisibility by 2 and 3, only test factors of the form 6k±1 up to sqrt(n).

### Threading Approach
- **Java**: Uses `Thread` with `AtomicLong` for thread-safe accumulation
- **Kotlin**: Uses `Executors.newFixedThreadPool` with futures for idiomatic JVM concurrency
- **Go**: Uses goroutines with `sync.WaitGroup`, per-chunk result slices for zero-contention accumulation

All use the number of available CPU cores as the thread/goroutine count.

### Timing
File I/O is performed before timing begins. Only computation time is measured, using nanosecond precision.
