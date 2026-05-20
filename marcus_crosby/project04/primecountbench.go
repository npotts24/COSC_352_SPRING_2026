package main

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run primecountbench.go <input-file> [thread-count]")
		return
	}

	inputPath := os.Args[1]
	threadCount := runtime.NumCPU()
	if len(os.Args) >= 3 {
		threadCount = parseThreadCount(os.Args[2], threadCount)
	}

	numbers, err := readNumbers(inputPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to read file: %v\n", err)
		return
	}

	if len(numbers) == 0 {
		fmt.Printf("No numbers found in file: %s\n", inputPath)
		return
	}

	singleStart := time.Now()
	singlePrimeCount := countPrimesSingleThread(numbers)
	singleElapsed := time.Since(singleStart)

	multiStart := time.Now()
	multiPrimeCount := countPrimesMultiThread(numbers, threadCount)
	multiElapsed := time.Since(multiStart)

	fmt.Printf("Input file: %s\n", inputPath)
	fmt.Printf("Total numbers parsed: %d\n\n", len(numbers))
	fmt.Println("Single-thread:")
	fmt.Printf("  Prime count: %d\n", singlePrimeCount)
	fmt.Printf("  Elapsed time: %.3f ms\n\n", float64(singleElapsed.Nanoseconds())/1_000_000.0)
	fmt.Printf("Multi-thread (%d threads):\n", threadCount)
	fmt.Printf("  Prime count: %d\n", multiPrimeCount)
	fmt.Printf("  Elapsed time: %.3f ms\n", float64(multiElapsed.Nanoseconds())/1_000_000.0)

	if singlePrimeCount != multiPrimeCount {
		fmt.Println("\nWarning: counts do not match between modes.")
	}
}

func parseThreadCount(text string, fallback int) int {
	parsed, err := strconv.Atoi(text)
	if err != nil || parsed < 1 {
		return fallback
	}
	return parsed
}

func readNumbers(path string) ([]int64, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	content := string(data)
	tokens := strings.FieldsFunc(content, func(r rune) bool {
		if r == '-' {
			return false
		}
		return r < '0' || r > '9'
	})

	numbers := make([]int64, 0, len(tokens))
	for _, token := range tokens {
		if token == "" || token == "-" {
			continue
		}
		n, err := strconv.ParseInt(token, 10, 64)
		if err != nil {
			continue
		}
		numbers = append(numbers, n)
	}

	return numbers, nil
}

func countPrimesSingleThread(numbers []int64) int64 {
	var count int64
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	return count
}

func countPrimesMultiThread(numbers []int64, threadCount int) int64 {
	size := len(numbers)
	workers := threadCount
	if workers > size {
		workers = size
	}
	if workers < 1 {
		workers = 1
	}

	chunkSize := (size + workers - 1) / workers
	results := make(chan int64, workers)
	var wg sync.WaitGroup

	for i := 0; i < size; i += chunkSize {
		from := i
		to := i + chunkSize
		if to > size {
			to = size
		}

		wg.Add(1)
		go func(start, end int) {
			defer wg.Done()
			var local int64
			for j := start; j < end; j++ {
				if isPrime(numbers[j]) {
					local++
				}
			}
			results <- local
		}(from, to)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	var total int64
	for local := range results {
		total += local
	}
	return total
}

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

	for i := int64(5); i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}
