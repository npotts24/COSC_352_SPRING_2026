package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
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
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	nums := make([]int64, 0, 1_000_000)

	scanner := bufio.NewScanner(f)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1024*1024)

	for scanner.Scan() {
		s := strings.TrimSpace(scanner.Text())
		if s == "" {
			continue
		}
		v, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			// skip invalid lines
			continue
		}
		nums = append(nums, v)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return nums, nil
}

func countPrimesSingle(nums []int64) int {
	count := 0
	for _, v := range nums {
		if isPrime(v) {
			count++
		}
	}
	return count
}

func countPrimesMulti(nums []int64, workers int) int {
	if workers < 1 {
		workers = 1
	}
	n := len(nums)
	if n == 0 {
		return 0
	}

	chunkSize := (n + workers - 1) / workers
	results := make(chan int, workers)

	launched := 0
	for start := 0; start < n; start += chunkSize {
		end := start + chunkSize
		if end > n {
			end = n
		}
		launched++
		go func(s, e int) {
			local := 0
			for i := s; i < e; i++ {
				if isPrime(nums[i]) {
					local++
				}
			}
			results <- local
		}(start, end)
	}

	total := 0
	for i := 0; i < launched; i++ {
		total += <-results
	}
	return total
}

func usage() {
	fmt.Println("Usage: go run golang/prime_counter.go <path-to-numbers.txt>")
	fmt.Println("Example: go run golang/prime_counter.go numbers.txt")
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}

	path := os.Args[1]
	if _, err := os.Stat(path); err != nil {
		fmt.Printf("Cannot read file: %s\n", path)
		usage()
		os.Exit(1)
	}

	nums, err := readNumbers(path)
	if err != nil {
		fmt.Printf("Error reading file: %v\n", err)
		os.Exit(1)
	}

	workers := runtime.NumCPU()
	if workers < 1 {
		workers = 1
	}

	sStart := time.Now()
	singleCount := countPrimesSingle(nums)
	singleMs := float64(time.Since(sStart).Nanoseconds()) / 1_000_000.0

	mStart := time.Now()
	multiCount := countPrimesMulti(nums, workers)
	multiMs := float64(time.Since(mStart).Nanoseconds()) / 1_000_000.0

	speedup := singleMs / multiMs

	fmt.Printf("File: %s (%s numbers)\n\n", filepath.Base(path), formatWithCommas(len(nums)))

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %s\n", formatWithCommas(singleCount))
	fmt.Printf("  Time: %.1f ms\n\n", singleMs)

	fmt.Printf("[Multi-Threaded] (%d threads)\n", workers)
	fmt.Printf("  Primes found: %s\n", formatWithCommas(multiCount))
	fmt.Printf("  Time: %.1f ms\n\n", multiMs)

	if singleCount != multiCount {
		fmt.Printf("WARNING: Counts differ! single=%d multi=%d\n", singleCount, multiCount)
	}

	fmt.Printf("Speedup: %.2fx\n", speedup)
}

func formatWithCommas(x int) string {
	s := strconv.Itoa(x)
	n := len(s)
	if n <= 3 {
		return s
	}
	var b strings.Builder
	pre := n % 3
	if pre == 0 {
		pre = 3
	}
	b.WriteString(s[:pre])
	for i := pre; i < n; i += 3 {
		b.WriteByte(',')
		b.WriteString(s[i : i+3])
	}
	return b.String()
}
