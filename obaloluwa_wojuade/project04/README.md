# Project 04 - Prime Counter (Java, Kotlin, Go)

This project solves the same problem in three languages:
- Java
- Kotlin
- Go

Each program:
1. Reads all numbers from a text file first.
2. Counts primes using a single-threaded loop.
3. Counts primes again using a multi-threaded approach.
4. Prints both times (ms) and the speedup.

## Files

- `java/PrimeCounter.java`
- `kotlin/PrimeCounter.kt`
- `golang/prime_counter.go`
- `run.sh`
- `data/numbers.txt`

## Prerequisites

Install these tools:
- `javac` / `java`
- `kotlinc`
- `go`
- `bash`

## Run

From this folder:

```bash
chmod +x run.sh
./run.sh data/numbers.txt
```

You can also pass your own file:

```bash
./run.sh /path/to/your_numbers.txt
```

## Notes

- Invalid lines and blank lines are skipped.
- Only numbers greater than 1 can be prime.
- The primality test uses trial division with `6k ± 1` optimization.
- Thread count defaults to available CPU cores.