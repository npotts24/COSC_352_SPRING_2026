package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"
)

func isPrime(n int) bool {
	if n <= 1 { return false }
	if n <= 3 { return true }
	if n%2 == 0 || n%3 == 0 { return false }
	for i := 5; i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 { return false }
	}
	return true
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run prime_counter.go <filename>")
		return
	}

	file, _ := os.Open(os.Args[1])
	scanner := bufio.NewScanner(file)
	var nums []int
	for scanner.Scan() {
		if val, err := strconv.Atoi(scanner.Text()); err == nil {
			nums = append(nums, val)
		}
	}

	// Single-Threaded
	start := time.Now()
	countST := 0
	for _, n := range nums {
		if isPrime(n) { countST++ }
	}
	durationST := time.Since(start)

	// Multi-Threaded
	numThreads := runtime.NumCPU()
	start = time.Now()
	var wg sync.WaitGroup
	counts := make([]int, numThreads)
	chunkSize := (len(nums) + numThreads - 1) / numThreads

	for i := 0; i < numThreads; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			startIdx := id * chunkSize
			endIdx := startIdx + chunkSize
			if endIdx > len(nums) { endIdx = len(nums) }
			for j := startIdx; j < endIdx; j++ {
				if isPrime(nums[j]) { counts[id]++ }
			}
		}(i)
	}
	wg.Wait()
	countMT := 0
	for _, v := range counts { countMT += v }
	durationMT := time.Since(start)

	fmt.Printf("[Single-Threaded]\n  Primes: %d\n  Time: %.2f ms\n", countST, float64(durationST.Nanoseconds())/1e6)
	fmt.Printf("[Multi-Threaded] (%d threads)\n  Primes: %d\n  Time: %.2f ms\n", numThreads, countMT, float64(durationMT.Nanoseconds())/1e6)
}