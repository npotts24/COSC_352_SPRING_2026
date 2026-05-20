# Prime Counter - Multi-Language Concurrency



## Overview

Counts prime numbers in three languages (Java, Kotlin, Go) using both single-threaded and multi-threaded approaches.

## Quick Start
```bash
# Generate test data
./generate_test_data.sh 10000 numbers.txt

# Run all programs
./run.sh numbers.txt
```

## Prerequisites

- Java JDK 11+
- Kotlin compiler
- Go 1.16+

## Install (Mac)
```bash
brew install kotlin go
```

## Project Structure
```
project04/
├── java/PrimeCounter.java
├── kotlin/PrimeCounter.kt
├── golang/prime_counter.go
├── run.sh
├── generate_test_data.sh
├── numbers.txt
└── README.md
```

## How It Works

1. Reads numbers from file
2. Counts primes single-threaded (sequential)
3. Counts primes multi-threaded (parallel)
4. Compares performance and shows speedup

## Algorithm

Uses optimized 6k±1 trial division for primality testing.


