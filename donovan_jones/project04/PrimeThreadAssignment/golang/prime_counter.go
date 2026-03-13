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

	file, _ := os.Open(os.Args[1])
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
	singleTime := time.Since(start)

	fmt.Println("\n[Single-Threaded]")
	fmt.Println("Primes found:", count)
	fmt.Println("Time:", singleTime.Milliseconds(), "ms")

	threads := runtime.NumCPU()
	chunk := len(numbers) / threads
	var wg sync.WaitGroup
	results := make(chan int, threads)

	start = time.Now()

	for i := 0; i < threads; i++ {
		from := i * chunk
		to := from + chunk
		if i == threads-1 {
			to = len(numbers)
		}

		wg.Add(1)
		go func(f, t int) {
			defer wg.Done()
			c := 0
			for j := f; j < t; j++ {
				if isPrime(numbers[j]) {
					c++
				}
			}
			results <- c
		}(from, to)
	}

	wg.Wait()
	close(results)

	total := 0
	for r := range results {
		total += r
	}

	multiTime := time.Since(start)

	fmt.Println("\n[Multi-Threaded]", threads, "threads")
	fmt.Println("Primes found:", total)
	fmt.Println("Time:", multiTime.Milliseconds(), "ms")
	fmt.Printf("\nSpeedup: %.2fx\n", float64(singleTime)/float64(multiTime))
}
