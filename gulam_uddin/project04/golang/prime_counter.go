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


func isPrime(n int) bool {
	if n < 2 {
		return false
	}
	if n == 2 {
		return true
	}
	if n%2 == 0 {
		return false
	}
	for i := 3; i*i <= n; i += 2 {
		if n%i == 0 {
			return false
		}
	}
	return true
}

func readNumbers(filename string) []int {
	file, _ := os.Open(filename)
	defer file.Close()

	var numbers []int
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		n, _ := strconv.Atoi(scanner.Text())
		numbers = append(numbers, n)
	}
	return numbers
}

func main() {
	filename := "testdata/numbers.txt"
	numbers := readNumbers(filename)

	runtime.GOMAXPROCS(runtime.NumCPU())
	threads := runtime.NumCPU()

	fmt.Printf("File: %s (%d numbers)\n", filename, len(numbers))
	fmt.Printf("CPU Cores Available: %d\n\n", threads)

	// Single-thread
	start := time.Now()
	count := 0
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	singleTime := time.Since(start)

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %,d\n", count)
	fmt.Printf("  Time: %.2f ms\n\n", float64(singleTime.Microseconds())/1000.0)

	// Multi-thread
	start = time.Now()
	var wg sync.WaitGroup
	chunkSize := len(numbers) / threads
	results := make(chan int, threads)

	for i := 0; i < threads; i++ {
		wg.Add(1)
		startIndex := i * chunkSize
		endIndex := startIndex + chunkSize
		if i == threads-1 {
			endIndex = len(numbers)
		}

		go func(start, end int) {
			defer wg.Done()
			local := 0
			for j := start; j < end; j++ {
				if isPrime(numbers[j]) {
					local++
				}
			}
			results <- local
		}(startIndex, endIndex)
	}

	wg.Wait()
	close(results)

	multiCount := 0
	for r := range results {
		multiCount += r
	}

	multiTime := time.Since(start)

	fmt.Println("[Multi-Threaded] (", threads, " threads)")
	fmt.Printf("  Primes found: %d\n", multiCount)
	fmt.Printf("  Time: %.2f ms\n\n", float64(multiTime.Microseconds())/1000.0)

	speedup := float64(singleTime) / float64(multiTime)
	fmt.Printf("Speedup: %.2fx\n", speedup)
}
