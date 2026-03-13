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

func readNumbers(filepath string) ([]int, error) {
	file, err := os.Open(filepath)
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
		num, err := strconv.Atoi(line)
		if err != nil {
			return nil, fmt.Errorf("invalid number: %s", line)
		}
		nums = append(nums, num)
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
		fmt.Printf("Error reading numbers: %v\n", err)
		return
	}

	fmt.Printf("File: %s (%d numbers)\n\n", filePath, len(numbers))

	startSingle := time.Now()
	singleCount := 0
	for _, n := range numbers {
		if isPrime(n) {
			singleCount++
		}
	}
	singleMs := float64(time.Since(startSingle).Microseconds()) / 1000.0

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
		go func(s, e, idx int) {
			defer wg.Done()
			c := 0
			for j := s; j < e; j++ {
				if isPrime(numbers[j]) {
					c++
				}
			}
			results <- c
		}(start, end, i)
	}

	wg.Wait()
	close(results)

	multiCount := 0
	for c := range results {
		multiCount += c
	}
	multiMs := float64(time.Since(startMulti).Microseconds()) / 1000.0

	fmt.Println("Single-threaded:")
	fmt.Printf("   primes found: %d\n", singleCount)
	fmt.Println("Multi-threaded:")
	fmt.Printf("   primes found: %d\n", multiCount)
	fmt.Printf("   time taken: %.2f ms\n", multiMs)

	if multiMs == 0.0 {
		fmt.Println("speedup: 0.00x")
	} else {
		fmt.Printf("speedup: %.2fx\n", singleMs/multiMs)
	}

}
