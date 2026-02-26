#!/bin/bash

# Build and run all three prime counter implementations
# Usage: ./run.sh [file_path]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE_PATH="${1:-$SCRIPT_DIR/numbers.txt}"

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH"
    echo "Usage: ./run.sh [file_path]"
    exit 1
fi

echo "=================================================================="
echo "Prime Counter - Multi-threaded Implementation"
echo "=================================================================="
echo "Input file: $FILE_PATH"
echo ""

cd "$SCRIPT_DIR"

# Compile Java
echo "[1/3] Compiling Java..."
javac java/PrimeCounter.java 2>&1 || { echo "Java compilation failed"; exit 1; }
echo "✓ Java compiled successfully"
echo ""

# Compile Kotlin
echo "[2/3] Compiling Kotlin..."
# Try to compile Kotlin using kotlinc if available
if command -v kotlinc &> /dev/null; then
    kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar 2>&1 || { 
        echo "Kotlin compilation failed"
        exit 1 
    }
    echo "✓ Kotlin compiled successfully"
else
    echo "⚠ kotlinc not found, skipping Kotlin compilation"
fi
echo ""

# Compile Go
echo "[3/3] Compiling Go..."
cd golang && go build -o prime_counter prime_counter.go 2>&1 || { 
    echo "Go compilation failed"
    exit 1 
}
cd ..
echo "✓ Go compiled successfully"
echo ""

echo "=================================================================="
echo "Running implementations..."
echo "=================================================================="
echo ""

# Run Java
echo ">>> JAVA IMPLEMENTATION <<<"
java -cp java PrimeCounter "$FILE_PATH" 2>/dev/null || echo "Java execution failed"
echo ""
echo "---"
echo ""

# Run Kotlin if compiled
if [ -f "kotlin/PrimeCounter.jar" ]; then
    echo ">>> KOTLIN IMPLEMENTATION <<<"
    java -jar kotlin/PrimeCounter.jar "$FILE_PATH" 2>/dev/null || echo "Kotlin execution failed"
    echo ""
    echo "---"
    echo ""
fi

# Run Go
echo ">>> GO IMPLEMENTATION <<<"
golang/prime_counter "$FILE_PATH" 2>/dev/null || echo "Go execution failed"

echo ""
echo "=================================================================="
echo "All implementations completed!"
echo "=================================================================="
