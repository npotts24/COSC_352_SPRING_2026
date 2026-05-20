#!/bin/bash

# Test data generator script
# Creates a file with random integers including edge cases

if [ $# -eq 0 ]; then
    NUM_ENTRIES=1000000
    FILENAME="testdata/numbers.txt"
else
    NUM_ENTRIES=$1
    FILENAME=${2:-"testdata/numbers.txt"}
fi

echo "Generating $NUM_ENTRIES numbers for testing..."

# Create output file
mkdir -p "$(dirname "$FILENAME")"
> "$FILENAME"  # Clear file if it exists

# Add some known edge cases first
echo "2" >> "$FILENAME"
echo "3" >> "$FILENAME"
echo "5" >> "$FILENAME"
echo "7" >> "$FILENAME"
echo "11" >> "$FILENAME"
echo "13" >> "$FILENAME"
echo "0" >> "$FILENAME"
echo "1" >> "$FILENAME"
echo "-5" >> "$FILENAME"
echo "100" >> "$FILENAME"

# Generate random numbers
# Mix of small numbers, medium numbers, and larger primes
for ((i = 10; i < NUM_ENTRIES; i++)); do
    # 70% random numbers, 30% numbers more likely to be prime
    if [ $((RANDOM % 100)) -lt 70 ]; then
        # Random number between 2 and 1000000
        echo $((RANDOM * 32 + RANDOM)) >> "$FILENAME"
    else
        # Numbers more likely to be prime (odd numbers, some primes)
        echo $((2 * RANDOM + 1)) >> "$FILENAME"
    fi
done

echo "Generated test file: $FILENAME with $NUM_ENTRIES entries"
wc -l "$FILENAME"
