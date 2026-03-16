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

func readNumbers(path string) ([]int64, error) {
	file, err := os.Open(path)
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
		value, err := strconv.ParseInt(line, 10, 64)
		if err != nil {
			continue
		}
		numbers = append(numbers, value)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return numbers, nil
}

func countPrimesSingle(numbers []int64) int64 {
	var count int64
	for _, value := range numbers {
		if isPrime(value) {
			count++
		}
	}
	return count
}

func countRange(numbers []int64, start, end int) int64 {
	var count int64
	for i := start; i < end; i++ {
		if isPrime(numbers[i]) {
			count++
		}
	}
	return count
}

func countPrimesMulti(numbers []int64, threads int) int64 {
	size := len(numbers)
	if size == 0 {
		return 0
	}

	chunkSize := (size + threads - 1) / threads
	results := make(chan int64, threads)
	var wg sync.WaitGroup

	for start := 0; start < size; start += chunkSize {
		end := start + chunkSize
		if end > size {
			end = size
		}

		wg.Add(1)
		go func(s, e int) {
			defer wg.Done()
			results <- countRange(numbers, s, e)
		}(start, end)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	var total int64
	for value := range results {
		total += value
	}
	return total
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: ./prime_counter <input-file>")
		return
	}

	filePath := os.Args[1]
	numbers, err := readNumbers(filePath)
	if err != nil {
		fmt.Printf("Could not read file: %s\n", filePath)
		fmt.Println("Usage: ./prime_counter <input-file>")
		return
	}

	threads := runtime.NumCPU()
	if threads < 1 {
		threads = 1
	}

	fmt.Printf("File: %s (%d numbers)\n\n", filePath, len(numbers))

	singleStart := time.Now()
	singleCount := countPrimesSingle(numbers)
	singleDuration := time.Since(singleStart)

	multiStart := time.Now()
	multiCount := countPrimesMulti(numbers, threads)
	multiDuration := time.Since(multiStart)

	singleMs := float64(singleDuration.Nanoseconds()) / 1_000_000.0
	multiMs := float64(multiDuration.Nanoseconds()) / 1_000_000.0
	speedup := 0.0
	if multiMs > 0 {
		speedup = singleMs / multiMs
	}

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %d\n", singleCount)
	fmt.Printf("  Time: %.3f ms\n\n", singleMs)

	fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
	fmt.Printf("  Primes found: %d\n", multiCount)
	fmt.Printf("  Time: %.3f ms\n\n", multiMs)

	if singleCount != multiCount {
		fmt.Println("WARNING: prime counts do not match.")
	}
	fmt.Printf("Speedup: %.2fx\n", speedup)
}
