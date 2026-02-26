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

func main() {

	if len(os.Args) < 2 {
		fmt.Println("Usage: go run prime_counter.go <file>")
		return
	}

	file, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Println("Error reading file")
		return
	}
	defer file.Close()

	var numbers []int64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		n, err := strconv.ParseInt(scanner.Text(), 10, 64)
		if err == nil {
			numbers = append(numbers, n)
		}
	}

	fmt.Printf("File: %s (%d numbers)\n", os.Args[1], len(numbers))

	start := time.Now()
	count := 0
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	singleTime := time.Since(start).Milliseconds()

	fmt.Println("\n[Single-Threaded]")
	fmt.Println("Primes found:", count)
	fmt.Println("Time:", singleTime, "ms")

	threads := runtime.NumCPU()
	runtime.GOMAXPROCS(threads)

	start = time.Now()

	chunkSize := len(numbers) / threads
	var wg sync.WaitGroup
	results := make(chan int, threads)

	for i := 0; i < threads; i++ {
		wg.Add(1)
		go func(start int) {
			defer wg.Done()
			end := start + chunkSize
			if end > len(numbers) {
				end = len(numbers)
			}
			local := 0
			for _, n := range numbers[start:end] {
				if isPrime(n) {
					local++
				}
			}
			results <- local
		}(i * chunkSize)
	}

	wg.Wait()
	close(results)

	total := 0
	for r := range results {
		total += r
	}

	multiTime := time.Since(start).Milliseconds()

	fmt.Println("\n[Multi-Threaded] (", threads, "threads )")
	fmt.Println("Primes found:", total)
	fmt.Println("Time:", multiTime, "ms")

	fmt.Printf("\nSpeedup: %.2fx\n", float64(singleTime)/float64(multiTime))
}
