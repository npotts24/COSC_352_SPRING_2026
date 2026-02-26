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

// Efficient primality test using 6k ± 1 method
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

	limit := int64(math.Sqrt(float64(n)))
	for i := int64(5); i <= limit; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

func readNumbers(filePath string) ([]int64, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var numbers []int64
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		num, err := strconv.ParseInt(line, 10, 64)
		if err != nil {
			continue
		}
		numbers = append(numbers, num)
	}

	return numbers, scanner.Err()
}

func countSingle(numbers []int64) int {
	count := 0
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	return count
}

func countMulti(numbers []int64, threads int) int {
	var wg sync.WaitGroup
	ch := make(chan int, threads)

	chunkSize := len(numbers) / threads

	for i := 0; i < threads; i++ {
		start := i * chunkSize
		end := start + chunkSize
		if i == threads-1 {
			end = len(numbers)
		}

		wg.Add(1)
		go func(nums []int64) {
			defer wg.Done()
			local := 0
			for _, n := range nums {
				if isPrime(n) {
					local++
				}
			}
			ch <- local
		}(numbers[start:end])
	}

	wg.Wait()
	close(ch)

	total := 0
	for c := range ch {
		total += c
	}
	return total
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run main.go <file_path>")
		os.Exit(1)
	}

	filePath := os.Args[1]

	numbers, err := readNumbers(filePath)
	if err != nil {
		fmt.Println("Error reading file:", err)
		os.Exit(1)
	}

	fmt.Printf("File: %s (%d numbers)\n\n", filePath, len(numbers))

	// Single-threaded
	startSingle := time.Now()
	singleCount := countSingle(numbers)
	elapsedSingle := time.Since(startSingle)

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %d\n", singleCount)
	fmt.Printf("  Time: %.3f ms\n\n", float64(elapsedSingle.Nanoseconds())/1e6)

	// Multi-threaded
	threads := runtime.NumCPU()
	runtime.GOMAXPROCS(threads)

	startMulti := time.Now()
	multiCount := countMulti(numbers, threads)
	elapsedMulti := time.Since(startMulti)

	fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
	fmt.Printf("  Primes found: %d\n", multiCount)
	fmt.Printf("  Time: %.3f ms\n\n", float64(elapsedMulti.Nanoseconds())/1e6)

	speedup := float64(elapsedSingle.Nanoseconds()) / float64(elapsedMulti.Nanoseconds())
	fmt.Printf("Speedup: %.2fx\n", speedup)
}