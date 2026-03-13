#  Configuration 

DEFAULT_TEST_FILE="numbers.txt"

# Determines the number of threads for multi-threading (can be adjusted)

NUM_THREADS=$(nproc 2>/dev/null || echo 4) # Use nproc, fallback to 4 if it fails

if [ "$NUM_THREADS" -lt 1 ]; then

    NUM_THREADS=4 # Ensure at least 1 thread

fi

#  Helper Function 

print_header() {

    echo e "\n\033[1;34m $1 \033[0m"

}

print_language_header() {

    echo e "\n\033[1;36m $1 \033[0m" 

}

print_result() {

    echo -e "\033[0;32m$1\033[0m" 

}

print_error() {

    echo -e "\033[0;31mError: $1\033[0m" >&2

}

#  Input File Handling 

INPUT_FILE=$1

if [ -z "$INPUT_FILE" ]; then

    echo "Usage: $0 <path_to_input_file>"

    echo "No input file provided. Using default: $DEFAULT_TEST_FILE"

    INPUT_FILE="$DEFAULT_TEST_FILE"

fi

if [ ! -f "$INPUT_FILE" ]; then

    print_error "Input file '$INPUT_FILE' not found."

   
    if [ "$INPUT_FILE" == "$DEFAULT_TEST_FILE" ]; then

        echo "Creating a dummy '$DEFAULT_TEST_FILE' for demonstration."


        echo "17" > "$DEFAULT_TEST_FILE"

        echo "4" >> "$DEFAULT_TEST_FILE"

        echo "29" >> "$DEFAULT_TEST_FILE"

        echo "100" >> "$DEFAULT_TEST_FILE"

        echo "7919" >> "$DEFAULT_TEST_FILE"

        echo "1" >> "$DEFAULT_TEST_FILE"

        echo "0" >> "$DEFAULT_TEST_FILE"

        echo "-5" >> "$DEFAULT_TEST_FILE"

        echo "104729" >> "$DEFAULT_TEST_FILE"

        echo "2" >> "$DEFAULT_TEST_FILE"

        echo "3" >> "$DEFAULT_TEST_FILE"

    else

        exit 1

    fi

fi

# Get the total number of lines for reporting

TOTAL_NUMBERS=$(wc -l < "$INPUT_FILE")

echo "Processing file: $INPUT_FILE ($TOTAL_NUMBERS numbers)"

echo "Using $NUM_THREADS threads for multi-threaded execution."

#  Source and Output Directories 

JAVA_SRC_DIR="java"

KOTLIN_SRC_DIR="kotlin"

GOLANG_SRC_DIR="golang"

mkdir -p "$JAVA_SRC_DIR" "$KOTLIN_SRC_DIR" "$GOLANG_SRC_DIR"

#  Java Implementation 

print_language_header "Java"

JAVA_MAIN_CLASS="PrimeCounter"

JAVA_SOURCE_FILE="$JAVA_SRC_DIR/$JAVA_MAIN_CLASS.java"

JAVA_CLASS_FILE="$JAVA_SRC_DIR/"


echo "Compiling Java..."

