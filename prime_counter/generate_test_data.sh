#!/bin/bash

# Test data generator for the prime counter assignment
# Usage: ./generate_test_data.sh [count] [output_file]

COUNT=${1:-100000}
OUTPUT_FILE=${2:-numbers.txt}

echo "Generating $COUNT random integers to $OUTPUT_FILE..."

# Generate random integers between 1 and 1,000,000
# Include some known primes and non-primes for verification
{
    echo "2"
    echo "3"
    echo "5"
    echo "7"
    echo "11"
    echo "13"
    echo "17"
    echo "19"
    echo "23"
    echo "29"
    echo "31"
    echo "37"
    echo "41"
    echo "43"
    echo "47"
    echo "53"
    echo "59"
    echo "61"
    echo "67"
    echo "71"
    echo "73"
    echo "79"
    echo "83"
    echo "89"
    echo "97"
    echo "101"
    echo "103"
    echo "107"
    echo "109"
    echo "113"
    echo "127"
    echo "131"
    echo "137"
    echo "139"
    echo "149"
    echo "151"
    echo "157"
    echo "163"
    echo "167"
    echo "173"
    echo "179"
    echo "181"
    echo "191"
    echo "193"
    echo "197"
    echo "199"
    echo "1"
    echo "0"
    echo "-5"
    echo "4"
    echo "6"
    echo "8"
    echo "9"
    echo "10"
    echo "100"
    echo "1000"
    echo "10000"
    
    # Generate remaining random numbers
    for ((i=0; i<$((COUNT-56)); i++)); do
        echo $((RANDOM * 32768 + RANDOM))
    done
} > "$OUTPUT_FILE"

echo "Done! Created $OUTPUT_FILE with $COUNT numbers."
echo "File size: $(du -h $OUTPUT_FILE | cut -f1)"
