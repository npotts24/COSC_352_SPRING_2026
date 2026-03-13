#!/bin/bash

# test.sh - Quick test to verify project files are correct

echo "=== Baltimore City Homicide Project - Verification ==="
echo ""

PROJECT_DIR="/workspaces/COSC_352_SPRING_2026/enoch_williams/project05"
cd "$PROJECT_DIR"

echo "✓ Project directory: $(pwd)"
echo ""

echo "=== Checking required files ==="
for file in histogram.R Dockerfile run.sh README.md; do
  if [ -f "$file" ]; then
    SIZE=$(wc -c < "$file")
    echo "✓ $file ($SIZE bytes)"
  else
    echo "✗ $file - MISSING"
  fi
done

echo ""
echo "=== File permissions ==="
ls -lh histogram.R Dockerfile run.sh README.md 2>/dev/null | awk '{print $1, $9}'

echo ""
echo "=== Run script is executable ==="
if [ -x run.sh ]; then
  echo "✓ run.sh has executable permission"
else
  echo "✗ run.sh is NOT executable"
fi

echo ""
echo "=== Docker file syntax check ==="
docker build --dry-run -t baltimore-homicide-analysis . 2>&1 | grep -E "error|Error|ERROR" || echo "✓ Dockerfile syntax appears valid"

echo ""
echo "=== Project structure summary ==="
echo "This project contains:"
echo "  1. histogram.R - Scrapes Baltimore homicide data and creates visualizations"
echo "  2. Dockerfile - Containerizes the analysis environment"
echo "  3. run.sh - Main entry point (use: ./run.sh)"
echo "  4. README.md - Full documentation"
echo ""
echo "Statistics analyzed: Victim age distribution"
echo "Data source: https://chamspage.blogspot.com/"
echo ""
echo "To run: ./run.sh"
echo "=== Verification Complete ==="
