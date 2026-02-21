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

// isPrime checks if a number is prime using optimized trial division
func isPrime(n int64) bool {
	if n <= 1 {
		return false
	}
	if n <= 3 {
		return true
	}
	if n%2 == 0 || n%3 == 0 {
		return false
	}

	// Only check divisors of form 6k ± 1 up to sqrt(n)
	for i := int64(5); i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

// countPrimesSingleThreaded counts primes sequentially
func countPrimesSingleThreaded(numbers []int64) int64 {
	count := int64(0)
	for _, num := range numbers {
		if isPrime(num) {
			count++
		}
	}
	return count
}

// countPrimesMultiThreaded counts primes using goroutines
func countPrimesMultiThreaded(numbers []int64, numWorkers int) int64 {
	chunkSize := (len(numbers) + numWorkers - 1) / numWorkers
	
	// Channel to collect results from each worker
	results := make(chan int64, numWorkers)
	var wg sync.WaitGroup
	
	// Launch worker goroutines
	for i := 0; i < numWorkers; i++ {
		start := i * chunkSize
		end := start + chunkSize
		if end > len(numbers) {
			end = len(numbers)
		}
		if start >= len(numbers) {
			break
		}
		
		wg.Add(1)
		go func(chunk []int64) {
			defer wg.Done()
			count := int64(0)
			for _, num := range chunk {
				if isPrime(num) {
					count++
				}
			}
			results <- count
		}(numbers[start:end])
	}
	
	// Close results channel when all workers are done
	go func() {
		wg.Wait()
		close(results)
	}()
	
	// Sum up all results
	total := int64(0)
	for count := range results {
		total += count
	}
	
	return total
}

// readNumbers reads integers from a file
func readNumbers(filename string) ([]int64, error) {
	file, err := os.Open(filename)
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
			fmt.Fprintf(os.Stderr, "Skipping invalid line: %s\n", line)
			continue
		}
		
		numbers = append(numbers, num)
	}
	
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	
	return numbers, nil
}

// formatNumber formats a number with thousands separators
func formatNumber(n int64) string {
	s := strconv.FormatInt(n, 10)
	if len(s) <= 3 {
		return s
	}
	
	var result strings.Builder
	for i, digit := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			result.WriteString(",")
		}
		result.WriteRune(digit)
	}
	return result.String()
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: go run prime_counter.go <input_file>")
		os.Exit(1)
	}
	
	filename := os.Args[1]
	
	// Read all numbers from file
	numbers, err := readNumbers(filename)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading file: %v\n", err)
		os.Exit(1)
	}
	
	if len(numbers) == 0 {
		fmt.Fprintln(os.Stderr, "No valid numbers found in file")
		os.Exit(1)
	}
	
	fmt.Printf("File: %s (%s numbers)\n", filename, formatNumber(int64(len(numbers))))
	fmt.Println()
	
	// Single-threaded approach
	fmt.Println("[Single-Threaded]")
	startSingle := time.Now()
	primesSingle := countPrimesSingleThreaded(numbers)
	timeSingle := time.Since(startSingle)
	
	fmt.Printf("  Primes found: %s\n", formatNumber(primesSingle))
	fmt.Printf("  Time: %.1f ms\n", float64(timeSingle.Nanoseconds())/1e6)
	fmt.Println()
	
	// Multi-threaded approach
	numWorkers := runtime.NumCPU()
	fmt.Printf("[Multi-Threaded] (%d threads)\n", numWorkers)
	startMulti := time.Now()
	primesMulti := countPrimesMultiThreaded(numbers, numWorkers)
	timeMulti := time.Since(startMulti)
	
	fmt.Printf("  Primes found: %s\n", formatNumber(primesMulti))
	fmt.Printf("  Time: %.1f ms\n", float64(timeMulti.Nanoseconds())/1e6)
	fmt.Println()
	
	// Speedup
	speedup := float64(timeSingle.Nanoseconds()) / float64(timeMulti.Nanoseconds())
	fmt.Printf("Speedup: %.2fx\n", speedup)
	
	// Verify results match
	if primesSingle != primesMulti {
		fmt.Fprintln(os.Stderr, "\nWARNING: Results don't match!")
		os.Exit(1)
	}
}