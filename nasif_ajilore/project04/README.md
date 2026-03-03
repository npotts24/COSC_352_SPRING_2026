# Multi-Language Prime Counter Benchmark

A comprehensive study of multi-threaded programming across three languages: **Java**, **Kotlin**, and **Go**. This project implements a prime number counter that processes a list of integers using both single-threaded and multi-threaded approaches.

## Overview

This project demonstrates how different languages implement concurrent programming to solve the same computational problem. Each implementation:

1. Reads a file containing integers (one per line)
2. Counts prime numbers using an efficient primality test
3. Runs the computation in two ways:
   - **Single-threaded**: Sequential processing
   - **Multi-threaded**: Parallel processing using language-specific concurrency primitives
4. Measures and compares performance with speedup ratio

## Project Structure

```
project04/
├── java/
│   └── PrimeCounter.java          # Java implementation using ExecutorService
├── kotlin/
│   └── PrimeCounter.kt            # Kotlin implementation (Java interop)
├── golang/
│   └── prime_counter.go           # Go implementation using goroutines
├── testdata/
│   ├── generate.sh                # Script to generate test data
│   └── numbers.txt                # Sample test file (auto-generated)
├── run.sh                         # Build and run all implementations
└── README.md                      # This file
```

## Algorithm Design

### Primality Test

All implementations use the same efficient trial division algorithm optimized with the 6k±1 pattern:

1. Handle special cases (n < 2, n = 2, n = 3)
2. Check divisibility by 2 and 3
3. Test only factors of the form 6k±1 up to √n
4. Time complexity: O(√n)

This approach is significantly more efficient than naive trial division while remaining simple and maintainable.

### File I/O

- All numbers are read from the file **before** any timing begins
- Invalid or blank lines are skipped gracefully
- Both single-threaded and multi-threaded approaches operate on the same data

### Single-Threaded Approach

A simple sequential loop through all numbers, counting primes incrementally.

```
For each number:
  if isPrime(number):
    increment counter
```

### Multi-Threaded Approach

Each language uses its native concurrency model:

#### Java
- **ExecutorService**: Fixed-size thread pool matching CPU core count
- Work is divided into chunks
- Each thread processes its chunk independently
- Results are collected and summed

#### Kotlin
- Leverages Kotlin's collection operations and Java interop
- Uses ExecutorService (same as Java for standard library compliance)
- More functional and idiomatic syntax
- Implicit parallel processing through chunking

#### Go
- **Goroutines**: Lightweight concurrency primitives
- **Channels**: Safe communication between goroutines
- Worker pool pattern with N goroutines (N = CPU core count)
- Numbers distributed through a buffered channel
- Results aggregated from result channel

## Prerequisites

### Java
- **JDK 8 or later** (Java 11+ recommended)
- `javac` compiler

### Kotlin
- **Kotlin compiler 1.6 or later**
- `kotlinc` command-line tool
- Java (Kotlin compiles to JVM bytecode)

Install Kotlin:
```bash
# Using SDKMAN (recommended)
sdk install kotlin

# Or download from https://kotlinlang.org/docs/command-line.html
```

### Go
- **Go 1.16 or later**
- `go` command-line tool

Install Go from: https://go.dev/doc/install

## Building

### Automatic Build (Recommended)

```bash
./run.sh [input_file]
```

The script will:
1. Check for required tools
2. Compile Java
3. Compile Kotlin to JAR
4. Build Go binary
5. Run all three implementations
6. Display results

### Manual Build

**Java:**
```bash
cd java
javac PrimeCounter.java
java PrimeCounter ../testdata/numbers.txt
```

**Kotlin:**
```bash
cd kotlin
kotlinc PrimeCounter.kt -include-runtime -d PrimeCounter.jar
java -jar PrimeCounter.jar ../testdata/numbers.txt
```

**Go:**
```bash
cd golang
go build -o prime_counter prime_counter.go
./prime_counter ../testdata/numbers.txt
```

## Running

### With Default Test Data

```bash
./run.sh
```

Automatically generates test data if it doesn't exist (100,000 numbers).

### With Custom Test File

```bash
./run.sh path/to/your/numbers.txt
```

### Generate Larger Test Data

```bash
bash testdata/generate.sh 1000000 testdata/large.txt
./run.sh testdata/large.txt
```

### Testing Individual Implementations

After building, run each one separately:

```bash
java -cp java/ PrimeCounter testdata/numbers.txt
java -jar kotlin/PrimeCounter.jar testdata/numbers.txt
./golang/prime_counter testdata/numbers.txt
```

## Expected Output

```
File: numbers.txt (1,000,000 numbers)

[Single-Threaded]
  Primes found: 78,498
  Time: 1823.4 ms

[Multi-Threaded] (8 threads)
  Primes found: 78,498
  Time: 312.7 ms

Speedup: 5.83x
```

## Language-Specific Design Decisions

### Java Implementation

**Why ExecutorService?**
- Standard JDK library (no external dependencies)
- Thread pool pattern is idiomatic Java
- Clear control over thread count and work distribution
- Natural fit for CPU-bound tasks

**Key Features:**
- `Executors.newFixedThreadPool()` for thread management
- `Callable<Long>` for per-chunk counting
- `Future.get()` for result collection
- `ExecutorService.shutdown()` for cleanup

**Why not Streams or Parallel Streams?**
- While `parallelStream()` would be simpler, using ExecutorService demonstrates explicit control
- Better shows the underlying threading mechanism
- More educational for comparing with other languages

### Kotlin Implementation

**Why ExecutorService (via Java)?**
- Kotlin targets the JVM; reusing Java libraries is idiomatic
- Demonstrates interoperability
- Standard library compliance

**Key Features:**
- Kotlin collection functions (`readLines()`, `chunked()`, `count()`, `sumOf()`)
- Extension functions and higher-order functions
- String interpolation for cleaner formatting
- Functional approach to data transformation
- `mapNotNull` for safe parsing

**Why not Coroutines?**
- Coroutines require `kotlinx.coroutines` (external dependency)
- ExecutorService demonstrates standard library only
- Still highly idiomatic and functional

### Go Implementation

**Why Goroutines?**
- Goroutines are Go's primary concurrency model
- Extremely lightweight (millions can run simultaneously)
- Natural fit for Go's design philosophy
- Vastly outperforms thread pools in raw efficiency

**Key Features:**
- Goroutine workers reading from a channel
- Buffered channel for work distribution (buffer size: 100)
- `sync.WaitGroup` for synchronization
- `close(channel)` for graceful shutdown
- `time.Now()` and `time.Since()` for timing

**Channel Design:**
- Producer: Main goroutine sends numbers to `numbersChan`
- Consumers: N worker goroutines read and process
- Aggregator: Separate goroutine closes channel after producer finishes
- Results collected from `resultsChan`

**Why not `runtime.GOMAXPROCS` manipulation?**
- Using `numCPU` worker goroutines is idiomatic
- Go runtime manages CPU assignment automatically
- More transparent and portable

## Performance Considerations

### Single-Threaded Performance
- Dominated by primality check count
- Memory access patterns (CPU cache affinity)
- Branch prediction in isPrime()

### Multi-Threaded Speedup
- Typically 4-8x on 8-core machines (not 8x due to overhead)
- Channel communication overhead (Go)
- Thread pool creation and synchronization (Java/Kotlin)
- GC pauses may impact results
- CPU contention with other processes

### Why Go May Be Faster
1. **Lightweight goroutines**: Minimal context-switch overhead
2. **Channel efficiency**: Production-grade concurrent design
3. **Compiled binary**: No JVM startup or GC pauses
4. **Better cache locality**: Go's threading model

### Why Java/Kotlin May Vary
1. **JVM startup time**: Not included in timing but affects small files
2. **Garbage collection**: May pause execution mid-benchmark
3. **JIT compilation**: Improves performance after warmup
4. **Platform support**: Consistent across OS through JVM

## Test Data

### Generating Custom Test Files

```bash
# 100,000 numbers (small)
bash testdata/generate.sh 100000 testdata/small.txt

# 1,000,000 numbers (medium)
bash testdata/generate.sh 1000000 testdata/medium.txt

# 5,000,000 numbers (large)
bash testdata/generate.sh 5000000 testdata/large.txt
```

The generator includes:
- Known primes: 2, 3, 5, 7, 11, 13
- Edge cases: 0, 1, -5
- Random integers for realistic distribution
- Mixture of small and large numbers

## Correctness Validation

All implementations verify that single-threaded and multi-threaded approaches produce identical results. If they differ, the program exits with an error message. This catches:

- Race conditions
- Integer overflow
- Calculation bugs
- Synchronization issues

## Troubleshooting

### "Command not found" errors

**Java/Kotlin:**
```bash
# Check if installed
which javac
which kotlinc

# Set JAVA_HOME if needed
export JAVA_HOME=/path/to/jdk
export PATH=$JAVA_HOME/bin:$PATH
```

**Go:**
```bash
# Check if installed
go version

# Install from https://go.dev/doc/install
```

### Kotlin compilation hangs

- First compilation is slower (JVM startup)
- Subsequent compilations are faster
- Consider using `kotlinc -J-Xmx4g` for large files

### File not found errors

Ensure the input file path is correct:
```bash
# Good
./run.sh testdata/numbers.txt

# Also good (relative path)
./run.sh ./testdata/numbers.txt

# From different directory
cd project04 && ./run.sh testdata/numbers.txt
```

### Out of memory on large files

Reduce file size or increase heap:
```bash
java -Xmx4g -cp java/ PrimeCounter testdata/large.txt
java -Xmx4g -jar kotlin/PrimeCounter.jar testdata/large.txt
```

## Project Learnings

This project demonstrates:

1. **Concurrency Models**: Different approaches to parallelism across languages
2. **Standard Library Usage**: Respecting language idioms and constraints
3. **Performance Tuning**: Trade-offs between simplicity and optimization
4. **Testing**: Correctness validation under concurrent execution
5. **Benchmarking**: Fair comparison across different platforms

## Extensions

Potential enhancements:

1. **Multiple runs with averaging**: Reduce JVM startup variance
2. **Adaptive chunk sizing**: Based on number range
3. **Lock-free algorithms**: Wait-free counters
4. **SIMD optimizations**: Vectorized primality checks (Go only)
5. **GPU computation**: For massive datasets
6. **Memory profiling**: Peak memory usage tracking
7. **Warm-up runs**: JIT compilation time

## References

- [Java Concurrency](https://docs.oracle.com/javase/tutorial/essential/concurrency/)
- [Kotlin Coroutines](https://kotlinlang.org/docs/coroutines-overview.html) (not used, but relevant)
- [Go Concurrency Patterns](https://go.dev/blog/pipelines)
- [Prime Checking Algorithms](https://en.wikipedia.org/wiki/Primality_test)

## License

This is an educational project for COSC 352 Spring 2026.

## Author

Nasif Ajilore
