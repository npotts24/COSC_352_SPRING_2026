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

func main() {

	if len(os.Args) < 2 {
		fmt.Println("Usage: go run prime_counter.go <file_path>")
		return
	}

	file, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Println("Error reading file.")
		return
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

	fmt.Printf("File: %s (%d numbers)\n\n", os.Args[1], len(numbers))

	// Single thread
	start1 := time.Now()
	var count1 int64
	for _, n := range numbers {
		if isPrime(n) {
			count1++
		}
	}
	time1 := time.Since(start1).Milliseconds()

	// Multi thread
	threads := runtime.NumCPU()
	start2 := time.Now()

	size := len(numbers)
	chunk := size / threads
	var wg sync.WaitGroup
	results := make(chan int64, threads)

	for t := 0; t < threads; t++ {

		start := t * chunk
		end := start + chunk
		if t == threads-1 {
			end = size
		}

		wg.Add(1)
		go func(start, end int) {
			defer wg.Done()
			var local int64
			for i := start; i < end; i++ {
				if isPrime(numbers[i]) {
					local++
				}
			}
			results <- local
		}(start, end)
	}

	wg.Wait()
	close(results)

	var count2 int64
	for r := range results {
		count2 += r
	}

	time2 := time.Since(start2).Milliseconds()

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %d\n", count1)
	fmt.Printf("  Time: %d ms\n\n", time1)

	fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
	fmt.Printf("  Primes found: %d\n", count2)
	fmt.Printf("  Time: %d ms\n\n", time2)

	fmt.Printf("Speedup: %.2fx\n", float64(time1)/float64(time2))
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