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

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: ./prime_counter <file_path>")
		os.Exit(1)
	}
	filePath := os.Args[1]
	numbers := readNumbers(filePath)
	if len(numbers) == 0 {
		fmt.Println("No valid numbers found in file.")
		os.Exit(1)
	}

	fmt.Printf("File: %s (%d numbers)\n", filePath, len(numbers))

	// Single-threaded
	start := time.Now()
	singleCount := countPrimesSingle(numbers)
	singleTime := time.Since(start).Milliseconds()

	fmt.Println("\n[Single-Threaded]")
	fmt.Printf("  Primes found: %d\n", singleCount)
	fmt.Printf("  Time: %d ms\n", singleTime)

	// Multi-threaded
	cores := runtime.NumCPU()
	start = time.Now()
	multiCount := countPrimesMulti(numbers, cores)
	multiTime := time.Since(start).Milliseconds()

	fmt.Println("\n[Multi-Threaded] (" + strconv.Itoa(cores) + " threads)")
	fmt.Printf("  Primes found: %d\n", multiCount)
	fmt.Printf("  Time: %d ms\n", multiTime)

	if multiTime > 0 {
		speedup := float64(singleTime) / float64(multiTime)
		fmt.Printf("Speedup: %.2fx\n", speedup)
	} else {
		fmt.Println("Speedup: N/A")
	}
}

func readNumbers(filePath string) []int64 {
	file, err := os.Open(filePath)
	if err != nil {
		fmt.Printf("Error reading file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	var numbers []int64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			if num, err := strconv.ParseInt(line, 10, 64); err == nil && num > 1 {
				numbers = append(numbers, num)
			}
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Printf("Error scanning file: %v\n", err)
		os.Exit(1)
	}
	return numbers
}

func countPrimesSingle(numbers []int64) int64 {
	var count int64
	for _, num := range numbers {
		if isPrime(num) {
			count++
		}
	}
	return count
}

func countPrimesMulti(numbers []int64, numThreads int) int64 {
	chunkSize := len(numbers) / numThreads
	remainder := len(numbers) % numThreads

	results := make(chan int64, numThreads)
	var wg sync.WaitGroup

	start := 0
	for i := 0; i < numThreads; i++ {
		end := start + chunkSize
		if i < remainder {
			end++
		}
		chunk := numbers[start:end]
		wg.Add(1)
		go func(chunk []int64) {
			defer wg.Done()
			var count int64
			for _, num := range chunk {
				if isPrime(num) {
					count++
				}
			}
			results <- count
		}(chunk)
		start = end
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	var totalCount int64
	for count := range results {
		totalCount += count
	}
	return totalCount
}

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
	for i := int64(5); i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}