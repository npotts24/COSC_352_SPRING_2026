#!/bin/bash

# Generate test data for prime counter
# Usage: ./generate_test_data.sh <num_lines> <output_file>

NUM_LINES="${1:-10000}"
OUTPUT_FILE="${2:-numbers.txt}"

echo "Generating $NUM_LINES random numbers..."

# Clear output file
> "$OUTPUT_FILE"

# Generate random numbers
for ((i=1; i<=$NUM_LINES; i++)); do
    # Generate mix of small and large numbers
    if [ $((RANDOM % 10)) -lt 3 ]; then
        # 30% small numbers (1-100)
        echo $((RANDOM % 100 + 1)) >> "$OUTPUT_FILE"
    elif [ $((RANDOM % 10)) -lt 6 ]; then
        # 30% medium numbers (100-10000)
        echo $((RANDOM % 9900 + 100)) >> "$OUTPUT_FILE"
    else
        # 40% large numbers (10000-1000000)
        echo $((RANDOM % 990000 + 10000)) >> "$OUTPUT_FILE"
    fi
done

echo "Generated $NUM_LINES numbers in $OUTPUT_FILE"
echo ""
echo "Sample (first 10 lines):"
head -10 "$OUTPUT_FILE"