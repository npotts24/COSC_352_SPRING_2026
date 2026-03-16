# Project 4: Multithreaded Programming Demonstration

This project implements a prime number counter in three programming languages (Java, Kotlin, and Go) to compare single-threaded vs multi-threaded performance.

## Overview

Each implementation reads numbers from a file and counts how many are prime using both:
1. Single-threaded approach - processes numbers sequentially
2. Multi-threaded approach - distributes work across multiple threads/goroutines/coroutines

The programs measure execution time for both approaches and calculate the speedup gained from multithreading.

## Project Structure

```
project04/
├── java/
│   └── PrimeCounter.java
├── kotlin/
│   └── PrimeCounter.kt
├── golang/
│   └── prime_counter.go
├── run.sh
├── numbers.txt
└── README.md
```

## Prerequisites

You need to have the following installed:

- **Java**: JDK 11 or higher
- **Kotlin**: Kotlin compiler (`kotlinc`)
- **Go**: Go 1.16 or higher

### Installation

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install default-jdk kotlin golang-go
```

**macOS:**
```bash
brew install openjdk kotlin go
```

**Windows:**
- Download and install from official websites
- Add to PATH

## Running the Project

### Quick Start

The easiest way is using the provided script:

```bash
chmod +x run.sh
./run.sh
```

This will compile and run all three implementations with the default `numbers.txt` file.

### Custom Input File

```bash
./run.sh your_numbers.txt
```

### Running Individually

**Java:**
```bash
javac java/PrimeCounter.java
java -cp java PrimeCounter numbers.txt
```

**Kotlin:**
```bash
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar
kotlin -classpath kotlin/PrimeCounter.jar PrimeCounterKt numbers.txt
```

**Go:**
```bash
go run golang/prime_counter.go numbers.txt
```

## Implementation Details

### Primality Testing
All implementations use an optimized trial division algorithm:
- Check divisibility by 2 and 3
- Then check only factors of form 6k±1 up to sqrt(n)

### Multithreading Approaches
- **Java**: Uses ExecutorService with a fixed thread pool and Futures
- **Kotlin**: Uses coroutines with async/await pattern and Dispatchers.Default
- **Go**: Uses goroutines with channels for result collection

### Thread Count
Each program automatically detects the number of available CPU cores and uses that for the multi-threaded approach.

## Input File Format

The input file should contain one integer per line:

```
17
4
29
100
7919
```

Invalid entries and blank lines are skipped.

## Sample Output

```
File: numbers.txt (31 numbers)

[Single-Threaded]
Primes found: 15
Time: 45.2 ms

[Multi-Threaded] (8 threads)
Primes found: 15
Time: 12.7 ms

Speedup: 3.56x
```

## Design Decisions

- File I/O is done before timing starts to ensure fair comparison
- High-resolution timing (nanoseconds) is used for accuracy
- Each language uses its idiomatic concurrency constructs
- Error handling includes file not found and invalid number formats

## Author

Karl Agli  
COSC 352 - Spring 2026
