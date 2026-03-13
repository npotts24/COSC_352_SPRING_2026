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

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run prime_counter.go <file>")
		return
	}

	numbers := readNumbers(os.Args[1])
	fmt.Printf("File: %s (%d numbers)\n\n", os.Args[1], len(numbers))

	startSingle := time.Now()
	singleCount := countSequential(numbers)
	singleTime := time.Since(startSingle).Milliseconds()

	threads := runtime.NumCPU()

	startMulti := time.Now()
	multiCount := countParallel(numbers, threads)
	multiTime := time.Since(startMulti).Milliseconds()

	printResults("Single-Threaded", singleCount, singleTime)
	printResults(fmt.Sprintf("Multi-Threaded (%d threads)", threads), multiCount, multiTime)

	fmt.Printf("Speedup: %.2fx\n", float64(singleTime)/float64(multiTime))
}

func readNumbers(path string) []int64 {
	file, _ := os.Open(path)
	defer file.Close()

	var numbers []int64
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		n, err := strconv.ParseInt(scanner.Text(), 10, 64)
		if err == nil {
			numbers = append(numbers, n)
		}
	}
	return numbers
}

func countSequential(numbers []int64) int {
	count := 0
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	return count
}

func countParallel(numbers []int64, threads int) int {
	var wg sync.WaitGroup
	ch := make(chan int, threads)

	chunk := len(numbers) / threads

	for i := 0; i < threads; i++ {
		start := i * chunk
		end := start + chunk
		if i == threads-1 {
			end = len(numbers)
		}

		wg.Add(1)
		go func(slice []int64) {
			defer wg.Done()
			count := 0
			for _, n := range slice {
				if isPrime(n) {
					count++
				}
			}
			ch <- count
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

func printResults(label string, count int, time int64) {
	fmt.Printf("[%s]\n", label)
	fmt.Printf("  Primes found: %d\n", count)
	fmt.Printf("  Time: %d ms\n\n", time)
}