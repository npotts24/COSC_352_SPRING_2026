package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
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
		fmt.Println("usage: golang_prime")
		return
	}

	file, _ := os.Open(os.Args[1])
	defer file.Close()
	var numbers []int64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		num, _ := strconv.ParseInt(scanner.Text(), 10, 64)
		numbers = append(numbers, num)
	}

	//single-threaded
	startS := time.Now()
	var countS int64
	for _, n := range numbers {
		if isPrime(n) {
			countS++
		}
	}
	timeS := time.Since(startS)

	//Multi-threaded
	cores := 8
	var countM int64
	var wg sync.WaitGroup
	chunkSize := int(math.Ceil(float64(len(numbers)) / float64(cores)))

	startM := time.Now()
	for i := 0; i < cores; i++ {
		startIdx := i * chunkSize
		endIdx := startIdx + chunkSize
		if endIdx > len(numbers) {
			endIdx = len(numbers)
		}

		wg.Add(1)
		go func(s, e int) {
			defer wg.Done()
			var localCount int64
			for j := s; j < e; j++ {
				if isPrime(numbers[j]) {
					localCount++
				}
			}
			atomic.AddInt64(&countM, localCount)
		}(startIdx, endIdx)
	}
	wg.Wait()
	timeM := time.Since(startM)

	//output
	fmt.Printf("[Single-threaded]\nPrimes found: %d\nTime: %.1f ms\n", countS, float64(timeS.Milliseconds()))
	fmt.Printf("[Multi-threaded] (%d threads)\nPrimes found: %d\nTime: %.1f ms\n", cores, countM, float64(timeM.Milliseconds()))
	fmt.Printf("\nSpeedup: %.2fx\n", float64(timeS)/float64(timeM))
}
