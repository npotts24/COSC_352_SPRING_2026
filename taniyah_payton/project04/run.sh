#!/usr/bin/env bash
# run.sh — Compile and run all three prime counter implementations.
# Usage: ./run.sh [file_path]
# Default: generates numbers.txt with 1,000,000 entries if no file is given.

set -euo pipefail

INPUT_FILE="${1:-numbers.txt}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Generate test data if needed ─────────────────────────────────────────────
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "No input file found. Generating '$INPUT_FILE' with 1,000,000 numbers..."
    python3 "$SCRIPT_DIR/generate_numbers.py" 1000000 "$INPUT_FILE"
    echo ""
fi

# ── Helpers ──────────────────────────────────────────────────────────────────
separator() { echo "──────────────────────────────────────────────────────────"; }
check_cmd()  { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found. Please install it."; exit 1; }; }

# ── Compile Java ─────────────────────────────────────────────────────────────
separator
echo "▶  Compiling Java..."
check_cmd javac
check_cmd java
javac "$SCRIPT_DIR/java/PrimeCounter.java" -d "$SCRIPT_DIR/java/"
echo "   Done."

# ── Compile Kotlin ───────────────────────────────────────────────────────────
separator
echo "▶  Compiling Kotlin..."
check_cmd kotlinc
kotlinc "$SCRIPT_DIR/kotlin/PrimeCounter.kt" -include-runtime -d "$SCRIPT_DIR/kotlin/PrimeCounter.jar" 2>/dev/null
echo "   Done."

# ── Build Go ─────────────────────────────────────────────────────────────────
separator
echo "▶  Building Go..."
check_cmd go
go build -o "$SCRIPT_DIR/golang/prime_counter" "$SCRIPT_DIR/golang/prime_counter.go"
echo "   Done."

# ── Run all three ────────────────────────────────────────────────────────────
separator
echo ""
echo "════════════════════════════════════════════════════════"
echo "  JAVA"
echo "════════════════════════════════════════════════════════"
java -cp "$SCRIPT_DIR/java/" PrimeCounter "$INPUT_FILE"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  KOTLIN"
echo "════════════════════════════════════════════════════════"
java -jar "$SCRIPT_DIR/kotlin/PrimeCounter.jar" "$INPUT_FILE"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  GO"
echo "════════════════════════════════════════════════════════"
"$SCRIPT_DIR/golang/prime_counter" "$INPUT_FILE"

separator
echo "Done. All three implementations completed."
