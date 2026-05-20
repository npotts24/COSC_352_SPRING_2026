package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

func isPrime(n int64) bool {
	if n < 2 {
		return false
	}
	if n == 2 {
		return true
	}
	if n%2 == 0 {
		return false
	}
	if n == 3 {
		return true
	}
	if n%3 == 0 {
		return false
	}
	sqrt := int64(math.Sqrt(float64(n)))
	for i := int64(5); i <= sqrt; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: prime_counter <file_path>")
		os.Exit(1)
	}
	filePath := os.Args[1]
	file, err := os.Open(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error opening file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	var numbers []int64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		n, err := strconv.ParseInt(line, 10, 64)
		if err == nil {
			numbers = append(numbers, n)
		}
	}
	fmt.Printf("File: %s (%s numbers)\n", filePath, formatInt(int64(len(numbers))))

	// Single-threaded
	start := time.Now()
	var singleCount int64
	for _, n := range numbers {
		if isPrime(n) {
			singleCount++
		}
	}
	singleDur := time.Since(start)
	fmt.Printf("[Single-Threaded] Primes found: %s  Time: %.1f ms\n", formatInt(singleCount), float64(singleDur.Nanoseconds())/1e6)

	// Multi-threaded using goroutines
	cores := runtime.NumCPU()
	chunkSize := (len(numbers) + cores - 1) / cores
	counts := make([]int64, cores)
	var wg sync.WaitGroup
	mStart := time.Now()
	for i := 0; i < cores; i++ {
		from := i * chunkSize
		to := from + chunkSize
		if to > len(numbers) {
			to = len(numbers)
		}
		if from >= len(numbers) {
			break
		}
		wg.Add(1)
		go func(slice []int64, idx int) {
			defer wg.Done()
			var local int64
			for _, n := range slice {
				if isPrime(n) {
					local++
				}
			}
			counts[idx] = local
		}(numbers[from:to], i)
	}
	wg.Wait()
	multiDur := time.Since(mStart)
	var multiCount int64
	for _, c := range counts {
		multiCount += c
	}
	fmt.Printf("[Multi-Threaded] (%d goroutines) Primes found: %s  Time: %.1f ms\n", cores, formatInt(multiCount), float64(multiDur.Nanoseconds())/1e6)
	fmt.Printf("Speedup: %.2fx\n", float64(singleDur.Nanoseconds())/float64(multiDur.Nanoseconds()))
}

func formatInt(n int64) string {
	s := strconv.FormatInt(n, 10)
	result := ""
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 && s[0] != '-' {
			result += ","
		}
		result += string(c)
	}
	return result
}
