# Project 04 - Prime Counter (Java, Kotlin, Go)

This project implements a multi-threaded prime number counter in three languages:
- **Java** - Using `ExecutorService` thread pools
- **Kotlin** - Using Kotlin concurrency and `ExecutorService`
- **Go** - Using goroutines and channels

Each program:
1. Reads all numbers from a text file
2. Counts primes using a **single-threaded** approach
3. Counts primes using a **multi-threaded** approach
4. Prints the count and timing (ms) for both
5. Calculates speedup ratio

## Quick Start (Recommended: Docker)

### Using Docker (All Dependencies Included - Recommended)

```bash
# Build the Docker image
docker build -t prime-counter .

# Run with default test data
docker run -v $(pwd)/data:/app/data prime-counter data/numbers.txt

# Run with your own file
docker run -v /path/to/your/data:/app/data prime-counter /app/data/your_file.txt
```

Docker automatically handles all dependencies and Java compatibility!

## Running Locally (Without Docker)

### Prerequisites

- **Java**: `openjdk-21-jdk` 
- **Kotlin**: `kotlin`
- **Go**: `go` (1.13+)

Install (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install openjdk-21-jdk kotlin golang-go
```

### Run All Implementations

```bash
chmod +x run.sh
./run.sh data/numbers.txt
```

With your own file:
```bash
./run.sh /path/to/your_numbers.txt
```

### Run Individual Languages

**Java Only:**
```bash
javac -d build/java java/PrimeCounter.java
java -cp build/java PrimeCounter data/numbers.txt
```

**Kotlin Only:**
```bash
kotlinc kotlin/PrimeCounter.kt -include-runtime -d build/kotlin/PrimeCounter.jar
java -jar build/kotlin/PrimeCounter.jar data/numbers.txt
```

**Go Only:**
```bash
cd golang && go build -o ../build/go/prime_counter prime_counter.go && cd ..
./build/go/prime_counter data/numbers.txt
```

## Project Structure

```
project04/
├── java/
│   └── PrimeCounter.java       # Java implementation
├── kotlin/
│   └── PrimeCounter.kt         # Kotlin implementation
├── golang/
│   └── prime_counter.go        # Go implementation
├── data/
│   └── numbers.txt             # Test data file
├── run.sh                       # Build and run script
├── Dockerfile                   # Docker configuration
└── README.md                    # This file
```

## Expected Output

```
========================================
Building Java
========================================

========================================
Building Kotlin
========================================

========================================
Building Go
========================================

========================================
Java Result
========================================
File: data/numbers.txt (100000 numbers)

[Single-Threaded]
  Primes found: 9,592
  Time: 1234.567 ms

[Multi-Threaded] (8 threads)
  Primes found: 9,592
  Time: 156.234 ms

Speedup: 7.90x

========================================
Kotlin Result
========================================
[Similar output...]

========================================
Go Result
========================================
[Similar output...]

========================================
Testing complete!
========================================
```

## Algorithm: Primality Check

Uses efficient trial division with 6k±1 optimization:

```
isPrime(n):
  if n < 2: return false
  if n == 2: return true
  if n % 2 == 0: return false
  if n == 3: return true
  if n % 3 == 0: return false
  
  for i = 5 to √n, step by 6:
    if n % i == 0 or n % (i+2) == 0:
      return false
  return true
```

## Concurrency Models

### Java: ExecutorService Thread Pool
- Creates fixed thread pool with CPU core count threads
- Submits work chunks as `Callable` tasks
- Collects results via `Future` objects

### Kotlin: ExecutorService with Kotlin Style
- Leverage Java interop for `ExecutorService`
- More concise syntax and idiomatic Kotlin
- Same underlying thread pool mechanism as Java

### Go: Goroutines + WaitGroup + Channels
- Spawns lightweight goroutines for each chunk
- Uses `sync.WaitGroup` for synchronization
- Aggregates results through channels
- Automatically leverages goroutine scheduler

## Performance Notes

### Expected Speedup

- **Small files** (< 10K): speedup < 1x (overhead dominates)
- **Medium files** (10K-100K): speedup 2-4x
- **Large files** (100K+): speedup 4-8x

### Test with Larger Data

```bash
# Generate 500,000 random numbers
python3 << 'EOF'
import random
for _ in range(500000):
    print(random.randint(1, 1000000))
EOF > data/large.txt

./run.sh data/large.txt
```

## Language Design Comparison

| Language | Concurrency | Overhead | Speedup |
|----------|-----------|----------|---------|
| Java | Thread Pool (ExecutorService) | Medium | Predictable |
| Kotlin | Thread Pool (Java interop) | Medium | Predictable |
| Go | Goroutines + Channels | Low | Excellent |

**Why each language?**

- **Java**: Standard library threading, broad compatibility, predictable performance
- **Kotlin**: Concise syntax, seamless Java interop, modern language features
- **Go**: Built for concurrency, lightweight goroutines, minimal overhead

## Input Format

Text file with one integer per line:
```
17
4
29
-5
0
1000000
```

**Parsing Rules:**
- One integer per line
- Blank lines are ignored
- Invalid lines are ignored
- Only numbers > 1 can be prime
- Negatives and zero are skipped

## Troubleshooting

### Docker Issues
All dependencies pre-installed, just run Docker. Recommended solution.

### Local: "Missing required command: kotlinc"
```bash
# Install Kotlin
sudo apt-get install kotlin

# Or upgrade
sudo apt-get install --only-upgrade kotlin
```

### Local: Java Version Error
Kotlin requires Java 21, not Java 25:
```bash
sudo apt-get install openjdk-21-jdk
```

### File Not Found
```bash
ls -la data/numbers.txt
./run.sh data/numbers.txt
```

## Verification

The program verifies that both single and multi-threaded approaches count the same primes:
```
if singleCount != multiCount:
  ERROR: Counts differ!
```

Both must match before displaying speedup.

## Notes

- All file I/O happens before timing (not included in measurements)
- Timing uses high-resolution nanosecond precision
- Results reported in milliseconds
- Thread count defaults to CPU core count
- Speedup = single-threaded time / multi-threaded time
