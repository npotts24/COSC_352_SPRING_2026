package main

import (
	"bufio"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"time"
)

func main() {

	if len(os.Args) < 2 {
		fmt.Println("Usage: go run prime_counter.go <file_path>")
		return
	}

	numbers := readFile(os.Args[1])
	fmt.Printf("File: %s (%d numbers)\n\n", os.Args[1], len(numbers))

	startSingle := time.Now()
	singleCount := countSingle(numbers)
	singleTime := time.Since(startSingle).Milliseconds()

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %d\n", singleCount)
	fmt.Printf("  Time: %d ms\n\n", singleTime)

	threads := runtime.NumCPU()
	startMulti := time.Now()
	multiCount := countMulti(numbers, threads)
	multiTime := time.Since(startMulti).Milliseconds()

	fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
	fmt.Printf("  Primes found: %d\n", multiCount)
	fmt.Printf("  Time: %d ms\n\n", multiTime)

	fmt.Printf("Speedup: %.2fx\n", float64(singleTime)/float64(multiTime))
}

func readFile(path string) []int64 {
	file, _ := os.Open(path)
	defer file.Close()

	var numbers []int64
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		if n, err := strconv.ParseInt(scanner.Text(), 10, 64); err == nil {
			numbers = append(numbers, n)
		}
	}
	return numbers
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

func countSingle(numbers []int64) int64 {
	var count int64
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	return count
}

func countMulti(numbers []int64, threads int) int64 {

	chunkSize := len(numbers) / threads
	results := make(chan int64, threads)

	for i := 0; i < threads; i++ {
		start := i * chunkSize
		end := start + chunkSize
		if i == threads-1 {
			end = len(numbers)
		}

		go func(slice []int64) {
			var count int64
			for _, n := range slice {
				if isPrime(n) {
					count++
				}
			}
			results <- count
		}(numbers[start:end])
	}

	var total int64
	for i := 0; i < threads; i++ {
		total += <-results
	}

	return total
}