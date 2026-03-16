# Project 04 - Prime Counter (Java, Kotlin, Go)

This project solves the same problem in three languages:

- `java/PrimeCounter.java`
- `kotlin/PrimeCounter.kt`
- `golang/prime_counter.go`

Each program:

1. Reads integers from a text file (one per line)
2. Skips blank and invalid lines gracefully
3. Counts primes in a single-threaded pass
4. Counts primes in a multi-threaded pass
5. Prints both timings and speedup

All implementations use the same primality test:

- Reject `n <= 1`
- Handle small cases (`2`, `3`)
- Reject divisibility by `2` and `3`
- Test only `6k ± 1` factors up to `sqrt(n)`

## Requirements

- Java JDK (for `javac` + `java`)
- Kotlin compiler (`kotlinc`)
- Go toolchain (`go`)
- Bash

No third-party libraries are used.

## Run Everything

From this folder:

```bash
./run.sh numbers.txt
```

or

```bash
bash run.sh numbers.txt
```

If no file is provided, `run.sh` uses `numbers.txt` by default.

## Generate Bigger Test Data

```bash
./generate_test_data.sh
```

Optional arguments:

```bash
./generate_test_data.sh output.txt 500000 5000000
```

- `output.txt` = output file path
- `500000` = number of random values
- `5000000` = max random magnitude

## Notes on Timing

- File reading/parsing is done **before** computation timing starts.
- Single-threaded timing runs first.
- Multi-threaded uses default thread count = available CPU cores.
- Timings are reported in milliseconds.
