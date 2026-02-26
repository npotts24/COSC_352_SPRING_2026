# Prime Counter — Multi-Language Multi-Threaded Benchmark

Counts prime numbers in a text file using single-threaded and multi-threaded approaches, implemented in **Java**, **Kotlin**, and **Go**.

---

## Prerequisites

| Tool | Minimum Version | Notes |
|------|----------------|-------|
| Java JDK | 11+ | `javac` + `java` must be on PATH |
| Kotlin | 1.6+ | `kotlinc` must be on PATH |
| Go | 1.18+ | `go` must be on PATH |
| Python 3 | 3.6+ | Only needed to auto-generate test data |

---

## Quick Start

```bash
# Run all three implementations with an auto-generated 1M-number file
chmod +x run.sh
./run.sh

# Or supply your own input file
./run.sh path/to/numbers.txt
```

The script compiles all three programs and then runs them sequentially, printing labeled output for easy side-by-side comparison.

---

## Input File Format

One integer per line. Blank lines and non-numeric entries are skipped silently.

```
17
4
29
-5
0
104729
```

Generate a test file manually:

```bash
python3 generate_numbers.py 1000000 numbers.txt
```

---

## Running Individual Programs

### Java
```bash
javac java/PrimeCounter.java -d java/
java -cp java/ PrimeCounter numbers.txt
```

### Kotlin
```bash
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar
java -jar kotlin/PrimeCounter.jar numbers.txt
```

### Go
```bash
go build -o golang/prime_counter golang/prime_counter.go
./golang/prime_counter numbers.txt
```

---

## Algorithm & Design Decisions

### Primality Check (all three languages)
Trial division optimized for the form **6k ± 1**:
1. Handle `n < 2`, `n == 2`, `n == 3` as base cases.
2. Quickly reject multiples of 2 and 3.
3. Test candidate factors `5, 7, 11, 13, 17, 19, ...` up to `√n`, stepping by 6.

This reduces the number of trial divisions by ~2/3 compared to naive trial division.

### Threading Model

Each language uses its own idiomatic concurrency primitive:

| Language | Mechanism |
|----------|-----------|
| **Java** | `ExecutorService` with `Callable<Long>` tasks submitted as `Future<Long>` |
| **Kotlin** | Same `ExecutorService` approach, expressed idiomatically with `chunked()` and `sumOf {}` |
| **Go** | Goroutines + `sync.WaitGroup` + buffered channel for results |

The number of threads/goroutines defaults to **the number of available CPU cores** (`Runtime.getRuntime().availableProcessors()` / `runtime.NumCPU()`).

### File I/O Excluded from Timing
All numbers are read and parsed into an in-memory list **before** either benchmark starts, so file I/O does not distort the timing comparison.

---

## Expected Output

```
File: numbers.txt (1,000,000 numbers)

[Single-Threaded]
  Primes found: 348,513
  Time: 2041.3 ms

[Multi-Threaded] (8 threads)
  Primes found: 348,513
  Time: 287.6 ms

Speedup: 7.10x
```

Speedup will vary based on core count and input size. Meaningful speedup is visible at ~100,000+ numbers.

---

## Project Structure

```
.
├── java/
│   └── PrimeCounter.java
├── kotlin/
│   └── PrimeCounter.kt
├── golang/
│   └── prime_counter.go
├── generate_numbers.py   # Test data generator
├── run.sh                # One-shot build + run script
└── README.md
```
