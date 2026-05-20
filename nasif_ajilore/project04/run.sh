#!/bin/bash

set -e

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Test file (use provided argument or default)
if [ $# -eq 0 ]; then
    TEST_FILE="testdata/numbers.txt"
    echo -e "${YELLOW}No input file provided. Using default: $TEST_FILE${NC}"
    
    # Generate test data if it doesn't exist
    if [ ! -f "$TEST_FILE" ]; then
        echo -e "${YELLOW}Test file not found. Generating test data...${NC}"
        bash testdata/generate.sh 100000 "$TEST_FILE"
        echo ""
    fi
else
    TEST_FILE="$1"
fi

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo -e "${RED}Error: Test file not found: $TEST_FILE${NC}" >&2
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Multi-Language Prime Counter Benchmark${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Input file:${NC} $TEST_FILE"
echo -e "${YELLOW}Number of entries:${NC} $(wc -l < "$TEST_FILE") lines\n"

# Check for required tools
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}" >&2
        return 1
    fi
    return 0
}

# Build and run Java version
build_and_run_java() {
    echo -e "${GREEN}[1/3] Java Implementation${NC}"
    echo -e "${YELLOW}------${NC}"
    
    if ! check_tool java; then
        echo -e "${RED}Skipping Java (java not found)${NC}\n"
        return 1
    fi
    
    if ! check_tool javac; then
        echo -e "${RED}Skipping Java (javac not found)${NC}\n"
        return 1
    fi
    
    echo "Compiling..."
    javac java/PrimeCounter.java -d java/
    
    echo "Running..."
    java -cp java/ PrimeCounter "$TEST_FILE"
    echo ""
    return 0
}

# Build and run Kotlin version
build_and_run_kotlin() {
    echo -e "${GREEN}[2/3] Kotlin Implementation${NC}"
    echo -e "${YELLOW}------${NC}"
    
    if ! check_tool kotlinc; then
        echo -e "${RED}Skipping Kotlin (kotlinc not found)${NC}"
        echo -e "${YELLOW}Install Kotlin: https://kotlinlang.org/docs/command-line.html${NC}\n"
        return 1
    fi
    
    if ! check_tool java; then
        echo -e "${RED}Skipping Kotlin (java not found)${NC}\n"
        return 1
    fi
    
    echo "Compiling..."
    kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar
    
    echo "Running..."
    java -jar kotlin/PrimeCounter.jar "$TEST_FILE"
    echo ""
    return 0
}

# Build and run Go version
build_and_run_go() {
    echo -e "${GREEN}[3/3] Go Implementation${NC}"
    echo -e "${YELLOW}------${NC}"
    
    if ! check_tool go; then
        echo -e "${RED}Skipping Go (go not found)${NC}"
        echo -e "${YELLOW}Install Go: https://go.dev/doc/install${NC}\n"
        return 1
    fi
    
    echo "Building..."
    cd golang
    go build -o prime_counter prime_counter.go
    cd ..
    
    echo "Running..."
    ./golang/prime_counter "$TEST_FILE"
    echo ""
    return 0
}

# Run all implementations
java_success=false
kotlin_success=false
go_success=false

build_and_run_java && java_success=true || true
build_and_run_kotlin && kotlin_success=true || true
build_and_run_go && go_success=true || true

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Build Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$java_success" = true ]; then
    echo -e "${GREEN}✓ Java${NC}"
else
    echo -e "${RED}✗ Java${NC}"
fi

if [ "$kotlin_success" = true ]; then
    echo -e "${GREEN}✓ Kotlin${NC}"
else
    echo -e "${RED}✗ Kotlin${NC}"
fi

if [ "$go_success" = true ]; then
    echo -e "${GREEN}✓ Go${NC}"
else
    echo -e "${RED}✗ Go${NC}"
fi

if [ "$java_success" = true ] && [ "$kotlin_success" = true ] && [ "$go_success" = true ]; then
    echo -e "\n${GREEN}All implementations completed successfully!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}Some implementations failed or were skipped.${NC}"
    echo -e "${YELLOW}Check the output above for details.${NC}"
    exit 1
fi
