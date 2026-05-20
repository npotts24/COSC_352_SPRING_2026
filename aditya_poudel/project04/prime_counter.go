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

// Efficient trial division: check 2, 3 then 6k±1 up to sqrt(n)
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
	for i := int64(5); i <= n/i; i += 6 { // avoids overflow vs i*i <= n
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

func countPrimesSingle(nums []int64) int64 {
	var count int64 = 0
	for _, x := range nums {
		if isPrime(x) {
			count++
		}
	}
	return count
}

func countPrimesMulti(nums []int64, threadsRequested int) int64 {
	n := len(nums)
	if n == 0 {
		return 0
	}

	threads := threadsRequested
	if threads < 1 {
		threads = 1
	}
	if threads > n {
		threads = n
	}

	chunkSize := (n + threads - 1) / threads

	var wg sync.WaitGroup
	results := make(chan int64, threads)

	for t := 0; t < threads; t++ {
		start := t * chunkSize
		end := start + chunkSize
		if end > n {
			end = n
		}
		if start >= end {
			break
		}

		wg.Add(1)
		go func(s, e int) {
			defer wg.Done()
			var local int64 = 0
			for i := s; i < e; i++ {
				if isPrime(nums[i]) {
					local++
				}
			}
			results <- local
		}(start, end)
	}

	wg.Wait()
	close(results)

	var total int64 = 0
	for v := range results {
		total += v
	}
	return total
}

func readAllNumbers(path string) ([]int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	nums := make([]int64, 0, 1024)
	scanner := bufio.NewScanner(f)

	// Support long lines if needed (not typical here, but safe).
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	for scanner.Scan() {
		s := strings.TrimSpace(scanner.Text())
		if s == "" {
			continue
		}
		v, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			continue // skip invalid lines gracefully
		}
		nums = append(nums, v)
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return nums, nil
}

func usage() {
	fmt.Println("Usage: prime_counter <path-to-numbers.txt>")
	fmt.Println("  File must contain one integer per line. Invalid/blank lines are skipped.")
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	path := os.Args[1]

	nums, err := readAllNumbers(path)
	if err != nil {
		fmt.Printf("Error: Cannot read file: %s\n", path)
		fmt.Printf("Details: %v\n", err)
		usage()
		os.Exit(1)
	}

	threads := runtime.NumCPU()

	fmt.Println("Language: Go")
	fmt.Printf("File: %s (%d numbers)\n\n", path, len(nums))

	t1Start := time.Now()
	singleCount := countPrimesSingle(nums)
	singleMs := float64(time.Since(t1Start).Nanoseconds()) / 1_000_000.0

	t2Start := time.Now()
	multiCount := countPrimesMulti(nums, threads)
	multiMs := float64(time.Since(t2Start).Nanoseconds()) / 1_000_000.0

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %d\n", singleCount)
	fmt.Printf("  Time: %.3f ms\n\n", singleMs)

	effectiveThreads := threads
	if effectiveThreads < 1 {
		effectiveThreads = 1
	}
	if effectiveThreads > len(nums) && len(nums) > 0 {
		effectiveThreads = len(nums)
	}
	if len(nums) == 0 {
		effectiveThreads = 1
	}

	fmt.Printf("[Multi-Threaded] (%d threads)\n", effectiveThreads)
	fmt.Printf("  Primes found: %d\n", multiCount)
	fmt.Printf("  Time: %.3f ms\n\n", multiMs)

	if singleCount != multiCount {
		fmt.Printf("WARNING: counts do not match! (single=%d, multi=%d)\n", singleCount, multiCount)
	}

	speedup := singleMs / multiMs
	fmt.Printf("Speedup: %.2fx\n", speedup)
}