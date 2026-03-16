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

// Required primality test: check 2 & 3, then 6k ± 1
func isPrime(n int) bool {
	if n <= 1 {
		return false
	}
	if n <= 3 {
		return true
	}
	if n%2 == 0 || n%3 == 0 {
		return false
	}
	for i := 5; i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

// Read all numbers before timing; skip blanks/invalid lines
func readNumbers(filePath string) ([]int, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var nums []int
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		n, err := strconv.Atoi(line)
		if err != nil {
			continue
		}
		nums = append(nums, n)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return nums, nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run prime_counter.go <file>")
		return
	}

	filePath := os.Args[1]
	numbers, err := readNumbers(filePath)
	if err != nil {
		fmt.Println("Error reading file:", filePath)
		fmt.Println("Usage: go run prime_counter.go <file>")
		return
	}

	fmt.Printf("File: %s (%d numbers)\n\n", filePath, len(numbers))

	// Single-threaded
	startSingle := time.Now()
	singleCount := 0
	for _, n := range numbers {
		if isPrime(n) {
			singleCount++
		}
	}
	singleMs := float64(time.Since(startSingle).Microseconds()) / 1000.0

	// Multi-threaded
	threads := runtime.NumCPU()
	runtime.GOMAXPROCS(threads)

	chunk := len(numbers) / threads
	if chunk < 1 {
		chunk = 1
	}

	startMulti := time.Now()
	results := make(chan int, threads)
	var wg sync.WaitGroup

	for i := 0; i < threads; i++ {
		start := i * chunk
		end := start + chunk
		if i == threads-1 || end > len(numbers) {
			end = len(numbers)
		}
		if start >= len(numbers) {
			break
		}

		wg.Add(1)
		go func(s, e int) {
			defer wg.Done()
			c := 0
			for j := s; j < e; j++ {
				if isPrime(numbers[j]) {
					c++
				}
			}
			results <- c
		}(start, end)
	}

	wg.Wait()
	close(results)

	multiCount := 0
	for r := range results {
		multiCount += r
	}
	multiMs := float64(time.Since(startMulti).Microseconds()) / 1000.0

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %d\n", singleCount)
	fmt.Printf("  Time: %.2f ms\n\n", singleMs)

	fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
	fmt.Printf("  Primes found: %d\n", multiCount)
	fmt.Printf("  Time: %.2f ms\n\n", multiMs)

	if multiMs == 0.0 {
		fmt.Println("Speedup: 0.00x")
	} else {
		fmt.Printf("Speedup: %.2fx\n", singleMs/multiMs)
	}
}
