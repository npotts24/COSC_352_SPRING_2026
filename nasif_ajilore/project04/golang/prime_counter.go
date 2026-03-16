package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

// isPrime checks if a number is prime using trial division optimized with 6k±1 pattern.
func isPrime(n int) bool {
	if n < 2 {
		return false
	}
	if n == 2 {
		return true
	}
	if n == 3 {
		return true
	}
	if n%2 == 0 {
		return false
	}
	if n%3 == 0 {
		return false
	}

	// Check factors of the form 6k±1 up to sqrt(n)
	for i := 5; i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

// readNumbers reads integers from file, skipping invalid entries.
func readNumbers(filePath string) ([]int, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var numbers []int
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		num, err := strconv.Atoi(line)
		if err != nil {
			// Skip invalid entries silently
			continue
		}
		numbers = append(numbers, num)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return numbers, nil
}

// countPrimesSingleThreaded counts primes sequentially.
func countPrimesSingleThreaded(numbers []int) int64 {
	var count int64
	for _, num := range numbers {
		if isPrime(num) {
			count++
		}
	}
	return count
}

// countPrimesMultiThreaded counts primes using goroutines.
func countPrimesMultiThreaded(numbers []int, numWorkers int) int64 {
	if numWorkers <= 0 {
		numWorkers = 1
	}

	// Create a channel to distribute work
	numbersChan := make(chan int, 100)
	resultsChan := make(chan int64, numWorkers)

	var wg sync.WaitGroup

	// Start worker goroutines
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			var count int64
			for num := range numbersChan {
				if isPrime(num) {
					count++
				}
			}
			resultsChan <- count
		}()
	}

	// Send numbers to workers
	go func() {
		for _, num := range numbers {
			numbersChan <- num
		}
		close(numbersChan)
	}()

	// Wait for all workers to finish
	go func() {
		wg.Wait()
		close(resultsChan)
	}()

	// Collect results
	var totalCount int64
	for count := range resultsChan {
		totalCount += count
	}

	return totalCount
}

// formatNumber formats a number with thousands separator.
func formatNumber(num int64) string {
	numStr := fmt.Sprintf("%d", num)
	result := ""
	count := 0

	for i := len(numStr) - 1; i >= 0; i-- {
		if count == 3 {
			result = "," + result
			count = 0
		}
		result = string(numStr[i]) + result
		count++
	}

	return result
}

// formatTime formats nanoseconds as milliseconds with 1 decimal place.
func formatTime(nanos int64) string {
	millis := float64(nanos) / 1_000_000.0
	return fmt.Sprintf("%.1f", millis)
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <file_path>\n", os.Args[0])
		os.Exit(1)
	}

	filePath := os.Args[1]

	// Read file
	numbers, err := readNumbers(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		os.Exit(1)
	}

	if len(numbers) == 0 {
		fmt.Fprintf(os.Stderr, "Error: File contains no valid integers.\n")
		os.Exit(1)
	}

	// Get file info
	fileName := filepath.Base(filePath)

	fmt.Printf("File: %s (%s numbers)\n\n", fileName, formatNumber(int64(len(numbers))))

	// Single-threaded run
	startTime := time.Now()
	countSingle := countPrimesSingleThreaded(numbers)
	durationSingle := time.Since(startTime).Nanoseconds()

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %s\n", formatNumber(countSingle))
	fmt.Printf("  Time: %s ms\n\n", formatTime(durationSingle))

	// Multi-threaded run
	numWorkers := runtime.NumCPU()
	startTime = time.Now()
	countMulti := countPrimesMultiThreaded(numbers, numWorkers)
	durationMulti := time.Since(startTime).Nanoseconds()

	fmt.Printf("[Multi-Threaded] (%d goroutines)\n", numWorkers)
	fmt.Printf("  Primes found: %s\n", formatNumber(countMulti))
	fmt.Printf("  Time: %s ms\n\n", formatTime(durationMulti))

	// Verify correctness
	if countSingle != countMulti {
		fmt.Fprintf(os.Stderr, "ERROR: Prime counts differ!\n")
		os.Exit(1)
	}

	// Calculate and display speedup
	speedup := float64(durationSingle) / float64(durationMulti)
	fmt.Printf("Speedup: %.2fx\n", speedup)
}
