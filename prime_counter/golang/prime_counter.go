package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// isPrime checks if a number is prime using trial division.
// After checking 2 and 3, only tests divisors of the form 6k±1 up to sqrt(n).
func isPrime(n int64) bool {
	if n < 2 {
		return false
	}
	if n == 2 {
		return true
	}
	if n%2 == 0 {
		return false
	}
	if n == 3 {
		return true
	}
	if n%3 == 0 {
		return false
	}

	sqrtN := int64(math.Sqrt(float64(n)))
	for i := int64(5); i <= sqrtN; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

// singleThreadedCount counts primes sequentially
func singleThreadedCount(numbers []int64) int64 {
	var count int64 = 0
	for _, num := range numbers {
		if isPrime(num) {
			count++
		}
	}
	return count
}

// multiThreadedCount distributes work across goroutines
func multiThreadedCount(numbers []int64, numWorkers int) int64 {
	chunkSize := (len(numbers) + numWorkers - 1) / numWorkers
	resultChan := make(chan int64, numWorkers)

	for i := 0; i < numWorkers; i++ {
		start := i * chunkSize
		end := start + chunkSize
		if end > len(numbers) {
			end = len(numbers)
		}

		if start >= len(numbers) {
			break
		}

		// Launch goroutine for this chunk
		go func(startIdx, endIdx int) {
			var count int64 = 0
			for j := startIdx; j < endIdx; j++ {
				if isPrime(numbers[j]) {
					count++
				}
			}
			resultChan <- count
		}(start, end)
	}

	// Collect results from all goroutines
	var totalCount int64 = 0
	for i := 0; i < numWorkers; i++ {
		start := i * chunkSize
		if start >= len(numbers) {
			break
		}
		totalCount += <-resultChan
	}

	return totalCount
}

// readNumbers reads integers from a file, one per line.
// Invalid or blank lines are skipped.
func readNumbers(filePath string) ([]int64, error) {
	var numbers []int64
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		num, err := strconv.ParseInt(line, 10, 64)
		if err != nil {
			// Skip invalid lines
			continue
		}
		numbers = append(numbers, num)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return numbers, nil
}

// formatNumber adds thousand separators to a number
func formatNumber(n interface{}) string {
	switch v := n.(type) {
	case int64:
		return formatInt(v)
	case int:
		return formatInt(int64(v))
	default:
		return fmt.Sprint(n)
	}
}

func formatInt(n int64) string {
	if n < 0 {
		return "-" + formatInt(-n)
	}
	if n < 1000 {
		return fmt.Sprint(n)
	}
	return fmt.Sprintf("%s,%03d", formatInt(n/1000), n%1000)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: go run prime_counter.go <file_path>\n")
		os.Exit(1)
	}

	filePath := os.Args[1]
	numbers, err := readNumbers(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		os.Exit(1)
	}

	if len(numbers) == 0 {
		fmt.Fprintf(os.Stderr, "No valid numbers found in file.\n")
		os.Exit(1)
	}

	// Get file info
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting file info: %v\n", err)
		os.Exit(1)
	}

	fileName := filepath.Base(filePath)
	fileSize := fileInfo.Size()
	fmt.Printf("File: %s (%s numbers, %s bytes)\n\n",
		fileName, formatNumber(int64(len(numbers))), formatNumber(fileSize))

	numThreads := runtime.NumCPU()

	// Single-threaded approach
	startTime := time.Now()
	primeCountSingle := singleThreadedCount(numbers)
	elapsedSingle := time.Since(startTime)
	elapsedMsSingle := elapsedSingle.Seconds() * 1000

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %s\n", formatNumber(primeCountSingle))
	fmt.Printf("  Time: %.1f ms\n\n", elapsedMsSingle)

	// Multi-threaded approach
	startTime = time.Now()
	primeCountMulti := multiThreadedCount(numbers, numThreads)
	elapsedMulti := time.Since(startTime)
	elapsedMsMulti := elapsedMulti.Seconds() * 1000

	fmt.Printf("[Multi-Threaded] (%d threads)\n", numThreads)
	fmt.Printf("  Primes found: %s\n", formatNumber(primeCountMulti))
	fmt.Printf("  Time: %.1f ms\n\n", elapsedMsMulti)

	// Calculate and display speedup
	speedup := elapsedMsSingle / elapsedMsMulti
	fmt.Printf("Speedup: %.2f x\n", speedup)

	// Verify both approaches found the same count
	if primeCountSingle != primeCountMulti {
		fmt.Fprintf(os.Stderr, "Error: Single-threaded (%d) and multi-threaded (%d) counts differ!\n",
			primeCountSingle, primeCountMulti)
		os.Exit(1)
	}
}
