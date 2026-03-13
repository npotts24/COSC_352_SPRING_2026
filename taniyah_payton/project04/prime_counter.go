package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

// isPrime checks primality using efficient trial division.
// After checking 2 and 3, only tests factors of the form 6k±1 up to sqrt(n).
func isPrime(n int64) bool {
	if n < 2 {
		return false
	}
	if n == 2 || n == 3 {
		return true
	}
	if n%2 == 0 || n%3 == 0 {
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

// readNumbers reads all valid integers from the file, skipping blank/invalid lines.
func readNumbers(filePath string) ([]int64, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	var numbers []int64
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		n, err := strconv.ParseInt(line, 10, 64)
		if err != nil {
			continue // skip invalid entries
		}
		numbers = append(numbers, n)
	}
	return numbers, scanner.Err()
}

// countPrimesSingleThreaded counts primes sequentially.
func countPrimesSingleThreaded(numbers []int64) int64 {
	var count int64
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	return count
}

// countPrimesMultiThreaded splits the slice into chunks and counts primes concurrently.
// Uses goroutines and channels — idiomatic Go concurrency.
func countPrimesMultiThreaded(numbers []int64, numWorkers int) int64 {
	total := len(numbers)
	if total == 0 {
		return 0
	}

	chunkSize := (total + numWorkers - 1) / numWorkers
	results := make(chan int64, numWorkers)
	var wg sync.WaitGroup

	for i := 0; i < total; i += chunkSize {
		end := i + chunkSize
		if end > total {
			end = total
		}
		chunk := numbers[i:end]

		wg.Add(1)
		go func(chunk []int64) {
			defer wg.Done()
			var count int64
			for _, n := range chunk {
				if isPrime(n) {
					count++
				}
			}
			results <- count
		}(chunk)
	}

	// Close results channel once all goroutines finish
	go func() {
		wg.Wait()
		close(results)
	}()

	var total64 int64
	for c := range results {
		total64 += c
	}
	return total64
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: prime_counter <file_path>")
		os.Exit(1)
	}

	filePath := os.Args[1]
	numbers, err := readNumbers(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		os.Exit(1)
	}

	numCPU := runtime.NumCPU()
	runtime.GOMAXPROCS(numCPU)

	fmt.Printf("File: %s (%s numbers)\n\n", filePath, formatInt(int64(len(numbers))))

	// Single-threaded
	stStart := time.Now()
	stCount := countPrimesSingleThreaded(numbers)
	stElapsed := time.Since(stStart)

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %s\n", formatInt(stCount))
	fmt.Printf("  Time: %.1f ms\n\n", float64(stElapsed.Nanoseconds())/1e6)

	// Multi-threaded
	mtStart := time.Now()
	mtCount := countPrimesMultiThreaded(numbers, numCPU)
	mtElapsed := time.Since(mtStart)

	fmt.Printf("[Multi-Threaded] (%d threads)\n", numCPU)
	fmt.Printf("  Primes found: %s\n", formatInt(mtCount))
	fmt.Printf("  Time: %.1f ms\n\n", float64(mtElapsed.Nanoseconds())/1e6)

	speedup := float64(stElapsed.Nanoseconds()) / float64(mtElapsed.Nanoseconds())
	fmt.Printf("Speedup: %.2fx\n", speedup)
}

// formatInt formats an int64 with comma separators.
func formatInt(n int64) string {
	s := strconv.FormatInt(n, 10)
	if len(s) <= 3 {
		return s
	}
	var result []byte
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			result = append(result, ',')
		}
		result = append(result, byte(c))
	}
	return string(result)
}
