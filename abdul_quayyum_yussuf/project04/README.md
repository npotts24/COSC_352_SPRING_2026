# Prime Counter Project

This project implements a prime number counter in Java, Kotlin, and Go. It reads a text file containing integers (one per line), counts how many are prime using both single-threaded and multi-threaded approaches, and reports the execution times and speedup.

## Prerequisites

- Java 17 or higher
- Kotlin 1.9 or higher
- Go 1.21 or higher
- Docker (optional, for simplified execution)

If Docker is available, the project will automatically use it to build and run in a containerized environment.

## How to Run

1. Ensure you have a text file with integers, one per line (e.g., `numbers.txt`).
2. Run the script: `./run.sh [file_path]`
   - If no file path is provided, it defaults to `numbers.txt`.
3. The script will compile the programs (if needed) and run each implementation, displaying the results side by side.

Example output:
```
File: numbers.txt (10000 numbers)

=== Java ===
[Single-Threaded]
  Primes found: 1,234
  Time: 123.4 ms

[Multi-Threaded] (8 threads)
  Primes found: 1,234
  Time: 45.6 ms

Speedup: 2.71x

=== Kotlin ===
...
```

## Design Decisions

- **Primality Check**: Uses an efficient trial division algorithm optimized for 6k±1 factors, checking up to the square root of n.
- **File Reading**: Reads all numbers into memory before computation to exclude I/O from timing. Skips invalid or non-positive lines.
- **Single-Threaded**: Simple sequential loop through the list.
- **Multi-Threaded**: Splits the list into chunks equal to the number of CPU cores. Each thread processes its chunk independently, and results are summed.
- **Timing**: Uses high-resolution timers (nanoseconds in Java/Kotlin, milliseconds in Go) and reports in milliseconds.
- **Threading Model**:
  - Java/Kotlin: Uses `ExecutorService` with `Callable` tasks.
  - Go: Uses goroutines with channels for result collection.
- **Docker**: Simplifies the build process by providing a consistent environment with all required tools pre-installed.

## File Structure

- `java/PrimeCounter.java`: Java implementation
- `kotlin/PrimeCounter.kt`: Kotlin implementation
- `golang/prime_counter.go`: Go implementation
- `run.sh`: Build-and-run script
- `generate.sh`: Test data generation script
- `README.md`: This documentation
- `Dockerfile`: Docker configuration (optional)