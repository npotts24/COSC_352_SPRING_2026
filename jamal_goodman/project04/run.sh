set -euo pipefail

FILE="${1:-numbers.txt}"

if [[ ! -f "$FILE" ]]; then
  echo "Input file not found: $FILE"
  echo "Tip: generate one with: ./generate_numbers.sh 1000000 numbers.txt"
  exit 1
fi

echo "============================================================"
echo "Project 04 - Prime Counter (Java / Kotlin / Go)"
echo "Input: $FILE"
echo "============================================================"
echo

echo ">>> Building Java..."
javac java/PrimeCounter.java
echo "------------------------------ JAVA ------------------------------"
java -cp java PrimeCounter "$FILE"
echo

echo ">>> Building Kotlin..."
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin/PrimeCounter.jar
echo "----------------------------- KOTLIN -----------------------------"
java -jar kotlin/PrimeCounter.jar "$FILE"
echo

echo ">>> Building Go..."
go build -o golang/prime_counter golang/prime_counter.go
echo "------------------------------- GO -------------------------------"
./golang/prime_counter "$FILE"
echo

echo "============================================================"
echo "Done."
echo "============================================================"
