# Project 04 - Prime Counter (Java / Kotlin / Go)

Counts how many primes appear in a text file (one integer per line).
Runs both single-threaded and multi-threaded versions and compares performance.

## Requirements
- Java JDK (11+ recommended)
- Kotlin compiler (`kotlinc`)
- Go (1.20+ recommended)
- Bash

No third-party libraries are used.

## Generate a test file
```bash
chmod +x generate_numbers.sh
./generate_numbers.sh 1000000 numbers.txt
