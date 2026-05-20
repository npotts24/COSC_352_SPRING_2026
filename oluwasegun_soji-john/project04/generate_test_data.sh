#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_FILE="${1:-$SCRIPT_DIR/numbers_generated.txt}"
COUNT="${2:-200000}"
MAX_VALUE="${3:-2000000}"

if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  echo "Error: COUNT must be a non-negative integer." >&2
  echo "Usage: ./generate_test_data.sh [output_file] [count] [max_value]" >&2
  exit 1
fi

if ! [[ "$MAX_VALUE" =~ ^[0-9]+$ ]] || [ "$MAX_VALUE" -le 1 ]; then
  echo "Error: MAX_VALUE must be an integer greater than 1." >&2
  echo "Usage: ./generate_test_data.sh [output_file] [count] [max_value]" >&2
  exit 1
fi

> "$OUT_FILE"

for ((i = 0; i < COUNT; i++)); do
  # Build a larger random number from two $RANDOM values.
  raw=$(( (RANDOM << 15) | RANDOM ))
  value=$(( raw % MAX_VALUE ))

  # Add negatives and zeros sometimes.
  case $((RANDOM % 10)) in
    0) value=0 ;;
    1) value=$((-value)) ;;
  esac

  echo "$value" >> "$OUT_FILE"
done

# Append a few known values.
cat <<EOF >> "$OUT_FILE"
2
3
5
7
11
13
17
7919
104729
999983
1000000
-10
EOF

total_lines=$((COUNT + 12))
echo "Generated $total_lines numbers in: $OUT_FILE"
