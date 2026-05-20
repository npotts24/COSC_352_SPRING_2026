# Prime Count Benchmarks


- `/Users/marco/Documents/Primecountbench.java`
- `/Users/marco/Documents/Primecountbench.kt`
- `/Users/marco/Documents/primecountbench.go`

Each program:
- Reads integers from a text file
- Counts how many are prime
- Runs both single-threaded and multi-threaded modes
- Prints elapsed time for each mode

## Input

Default sample input:
- `/Users/marco/Documents/sample_numbers.txt`

You can pass your own input file path and optional thread count.

## Run All (Recommended)

Use the helper script:

```bash
cd /Users/marco/Documents/
./build.sh [input-file] [thread-count]
```

Examples:

```bash
./build.sh
./build.sh /Users/marco/Documents/sample_numbers.txt 4
```

The script will:
1. Compile and run Java
2. Compile and run Kotlin
3. Build and run Go

If a toolchain is missing, that section is skipped.

## Run Individually

### Java

```bash
cd /Users/marco/Documents/
javac Primecountbench.java
java Primecountbench sample_numbers.txt 4
```

### Kotlin

```bash
cd /Users/marco/Documents/
kotlinc Primecountbench.kt -include-runtime -d Primecountbench.jar
java -jar Primecountbench.jar sample_numbers.txt 4
```

### Go

```bash
cd /Users/marco/Documents/
go run primecountbench.go sample_numbers.txt 4
```

## Requirements

- Java: `javac` and `java`
- Kotlin: `kotlinc` and `java`
- Go: `go`

All three programs use only their language standard libraries.
