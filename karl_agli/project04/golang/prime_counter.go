package main

import (
	"bufio"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Check if a number is prime using trial division
func isPrime(n int64) bool {
	if n <= 1 {
		return false
	}
	if n == 2 || n == 3 {
		return true
	}
	if n%2 == 0 || n%3 == 0 {
		return false
	}
	
	// Check factors of form 6k±1 up to sqrt(n)
	for i := int64(5); i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

// Count primes sequentially
func countPrimesSingleThreaded(numbers []int64) int {
	count := 0
	for _, num := range numbers {
		if isPrime(num) {
			count++
		}
	}
	return count
}

// Count primes using goroutines
func countPrimesMultiThreaded(numbers []int64, threadCount int) int {
	chunkSize := (len(numbers) + threadCount - 1) / threadCount
	var wg sync.WaitGroup
	results := make(chan int, threadCount)
	
	for i := 0; i < threadCount; i++ {
		start := i * chunkSize
		if start >= len(numbers) {
			break
		}
		end := start + chunkSize
		if end > len(numbers) {
			end = len(numbers)
		}
		
		wg.Add(1)
		go func(nums []int64) {
			defer wg.Done()
			localCount := 0
			for _, num := range nums {
				if isPrime(num) {
					localCount++
				}
			}
			results <- localCount
		}(numbers[start:end])
	}
	
	go func() {
		wg.Wait()
		close(results)
	}()
	
	totalCount := 0
	for count := range results {
		totalCount += count
	}
	
	return totalCount
}

// Read numbers from file
func readNumbersFromFile(filePath string) ([]int64, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	
	var numbers []int64
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

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run prime_counter.go <input_file>")
		os.Exit(1)
	}
	
	filePath := os.Args[1]
	
	// Read all numbers first
	numbers, err := readNumbersFromFile(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		os.Exit(1)
	}
	
	if len(numbers) == 0 {
		fmt.Println("No valid numbers found in file")
		os.Exit(1)
	}
	
	fmt.Printf("File: %s (%s numbers)\n", filePath, formatNumber(len(numbers)))
	
	// Single-threaded approach
	startTime := time.Now()
	singleThreadedCount := countPrimesSingleThreaded(numbers)
	singleThreadedTime := time.Since(startTime).Seconds() * 1000
	
	fmt.Println("\n[Single-Threaded]")
	fmt.Printf("Primes found: %s\n", formatNumber(singleThreadedCount))
	fmt.Printf("Time: %.1f ms\n", singleThreadedTime)
	
	// Multi-threaded approach using goroutines
	threadCount := runtime.NumCPU()
	startTime = time.Now()
	multiThreadedCount := countPrimesMultiThreaded(numbers, threadCount)
	multiThreadedTime := time.Since(startTime).Seconds() * 1000
	
	fmt.Printf("\n[Multi-Threaded] (%d threads)\n", threadCount)
	fmt.Printf("Primes found: %s\n", formatNumber(multiThreadedCount))
	fmt.Printf("Time: %.1f ms\n", multiThreadedTime)
	
	speedup := singleThreadedTime / multiThreadedTime
	fmt.Printf("\nSpeedup: %.2fx\n", speedup)
}

// Format number with thousands separator
func formatNumber(n int) string {
	s := strconv.Itoa(n)
	if len(s) <= 3 {
		return s
	}
	
	var result []byte
	for i, digit := range []byte(s) {
		if i > 0 && (len(s)-i)%3 == 0 {
			result = append(result, ',')
		}
		result = append(result, digit)
	}
	return string(result)
}
