# Project 04 – Multi-Threaded Prime Counter

## Overview

This project demonstrates multi-threaded programming in:

- Java
- Kotlin
- Go

Each implementation:
- Reads integers from a file
- Counts prime numbers
- Runs both single-threaded and multi-threaded versions
- Measures execution time
- Computes speedup

---

## Design Decisions

### Primality Algorithm
Uses optimized trial division:
- Check divisibility by 2 and 3
- Test only 6k ± 1 values up to √n

Time complexity per number: O(√n)

---

### Multi-Threading Strategy

- Numbers are split into equal chunks
- Threads = number of available CPU cores
- Each thread independently counts primes
- Results aggregated at the end
- No shared mutable state (avoids race conditions)

---

## How To Run

```bash
./run.sh testdata/numbers.txt
