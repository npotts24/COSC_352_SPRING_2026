package main

import (
	"bufio"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"
)

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

func readNumbers(filePath string) ([]int64, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var numbers []int64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		n, err := strconv.ParseInt(line, 10, 64)
		if err == nil {
			numbers = append(numbers, n)
		}
	}
	return numbers, nil
}

func main() {

	if len(os.Args) != 2 {
		fmt.Println("Usage: go run prime_counter.go <input_file>")
		return
	}

	filePath := os.Args[1]
	numbers, err := readNumbers(filePath)
	if err != nil {
		fmt.Println("Error reading file:", filePath)
		return
	}

	fmt.Printf("File: %s (%d numbers)\n", filePath, len(numbers))

	// Single-threaded
	start := time.Now()
	singleCount := 0
	for _, n := range numbers {
		if isPrime(n) {
			singleCount++
		}
	}
	singleTime := time.Since(start)

	// Multi-threaded
	numThreads := runtime.NumCPU()
	chunkSize := len(numbers) / numThreads
	var wg sync.WaitGroup
	results := make(chan int, numThreads)

	start = time.Now()
	for i := 0; i < numThreads; i++ {
		startIdx := i * chunkSize
		endIdx := startIdx + chunkSize
		if i == numThreads-1 {
			endIdx = len(numbers)
		}

		wg.Add(1)
		go func(nums []int64) {
			defer wg.Done()
			count := 0
			for _, n := range nums {
				if isPrime(n) {
					count++
				}
			}
			results <- count
		}(numbers[startIdx:endIdx])
	}

	wg.Wait()
	close(results)

	multiCount := 0
	for c := range results {
		multiCount += c
	}
	multiTime := time.Since(start)

	fmt.Println("\n[Single-Threaded]")
	fmt.Println("  Primes found:", singleCount)
	fmt.Println("  Time:", singleTime.Milliseconds(), "ms")

	fmt.Printf("\n[Multi-Threaded] (%d threads)\n", numThreads)
	fmt.Println("  Primes found:", multiCount)
	fmt.Println("  Time:", multiTime.Milliseconds(), "ms")

	if multiTime > 0 {
		fmt.Printf("\nSpeedup: %.2fx\n", float64(singleTime)/float64(multiTime))
	}
}
