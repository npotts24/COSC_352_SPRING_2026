# Project 04 – Multi-Threaded Prime Counter

## Description

This project implements a prime number counter in three programming languages:

- Java
- Kotlin
- Go

Each implementation:
- Reads integers from a text file (one per line)
- Counts prime numbers using:
  - Single-threaded approach
  - Multi-threaded approach
- Uses efficient 6k ± 1 primality testing
- Measures execution time (nanosecond precision)
- Reports speedup

Only standard libraries are used.

---

## Build Requirements

- Java (OpenJDK)
- Kotlin
- Go
- Bash

---

## How To Run

From inside project04:



Or simply:



(Default input: test_numbers.txt)

---

## Output Example

Each language prints:

- Number of primes found
- Execution time (ms)
- Speedup ratio

---

## Design Decisions

- File is fully read before timing begins.
- Work is divided evenly among CPU cores.
- Threads use language-native concurrency:
  - Java: ExecutorService
  - Kotlin: Executors
  - Go: Goroutines + WaitGroup
- Trial division optimized using 6k ± 1 method.

---

## Author

Sandeep Shah
COSC 352
