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
	for i := int64(5); i <= n/i; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

func readAllNumbers(path string) ([]int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	nums := make([]int64, 0, 1024)
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		s := strings.TrimSpace(sc.Text())
		if s == "" {
			continue
		}
		v, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			continue // skip invalid line gracefully
		}
		nums = append(nums, v)
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	return nums, nil
}

func countSingle(nums []int64) int64 {
	var count int64
	for _, x := range nums {
		if isPrime(x) {
			count++
		}
	}
	return count
}

func countParallel(nums []int64, threads int) int64 {
	n := len(nums)
	if n == 0 {
		return 0
	}
	t := threads
	if t < 1 {
		t = 1
	}
	if t > n {
		t = n
	}

	chunk := (n + t - 1) / t
	results := make(chan int64, t)

	var wg sync.WaitGroup
	for i := 0; i < t; i++ {
		start := i * chunk
		end := start + chunk
		if end > n {
			end = n
		}
		if start >= end {
			break
		}

		wg.Add(1)
		go func(a, b int) {
			defer wg.Done()
			var local int64
			for _, x := range nums[a:b] {
				if isPrime(x) {
					local++
				}
			}
			results <- local
		}(start, end)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	var total int64
	for v := range results {
		total += v
	}
	return total
}

func usage() {
	fmt.Println("Usage: ./prime_counter <path/to/numbers.txt>")
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	path := os.Args[1]

	nums, err := readAllNumbers(path) // I/O done BEFORE timing
	if err != nil {
		fmt.Printf("Error: cannot read file: %s\n", path)
		usage()
		os.Exit(1)
	}

	threads := runtime.NumCPU()

	fmt.Printf("File: %s (%d numbers)\n\n", path, len(nums))

	t1 := time.Now()
	single := countSingle(nums)
	singleMs := float64(time.Since(t1).Nanoseconds()) / 1_000_000.0

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %s\n", comma(single))
	fmt.Printf("  Time: %.3f ms\n\n", singleMs)

	t2 := time.Now()
	multi := countParallel(nums, threads)
	multiMs := float64(time.Since(t2).Nanoseconds()) / 1_000_000.0

	fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
	fmt.Printf("  Primes found: %s\n", comma(multi))
	fmt.Printf("  Time: %.3f ms\n\n", multiMs)

	if single != multi {
		fmt.Printf("WARNING: Counts do not match! single=%d multi=%d\n", single, multi)
	}

	fmt.Printf("Speedup: %.2fx\n", singleMs/multiMs)
}

func comma(n int64) string {
	s := strconv.FormatInt(n, 10)
	if len(s) <= 3 {
		return s
	}
	var b strings.Builder
	pre := len(s) % 3
	if pre == 0 {
		pre = 3
	}
	b.WriteString(s[:pre])
	for i := pre; i < len(s); i += 3 {
		b.WriteByte(',')
		b.WriteString(s[i : i+3])
	}
	return b.String()
}
