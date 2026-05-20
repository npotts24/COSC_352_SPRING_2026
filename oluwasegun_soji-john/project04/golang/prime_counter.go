package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

type InputData struct {
	Numbers      []int64
	InvalidLines int
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

func readNumbers(filePath string) (InputData, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return InputData{}, err
	}
	defer file.Close()

	var numbers []int64
	invalid := 0

	scanner := bufio.NewScanner(file)
	buf := make([]byte, 0, 1024*1024)
	scanner.Buffer(buf, 1024*1024*64)

	for scanner.Scan() {
		trimmed := strings.TrimSpace(scanner.Text())
		if trimmed == "" {
			continue
		}

		value, parseErr := strconv.ParseInt(trimmed, 10, 64)
		if parseErr != nil {
			invalid++
			continue
		}
		numbers = append(numbers, value)
	}

	if err := scanner.Err(); err != nil {
		return InputData{}, err
	}

	return InputData{Numbers: numbers, InvalidLines: invalid}, nil
}

func countPrimesSingleThreaded(numbers []int64) int64 {
	var count int64 = 0
	for _, n := range numbers {
		if isPrime(n) {
			count++
		}
	}
	return count
}

func determineWorkerCount(totalNumbers int, availableCores int) int {
	safeCores := availableCores
	if safeCores < 1 {
		safeCores = 1
	}
	if totalNumbers <= 0 {
		return 1
	}
	if safeCores > totalNumbers {
		return totalNumbers
	}
	return safeCores
}

func countPrimesMultiThreaded(numbers []int64, workers int) int64 {
	if len(numbers) == 0 {
		return 0
	}

	results := make(chan int64, workers)
	var wg sync.WaitGroup

	total := len(numbers)
	for i := 0; i < workers; i++ {
		start := i * total / workers
		end := (i + 1) * total / workers

		wg.Add(1)
		go func(s int, e int) {
			defer wg.Done()
			var local int64 = 0
			for _, n := range numbers[s:e] {
				if isPrime(n) {
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

	var totalCount int64 = 0
	for c := range results {
		totalCount += c
	}
	return totalCount
}

func formatWithCommas(value int64) string {
	sign := ""
	if value < 0 {
		sign = "-"
		value = -value
	}

	s := strconv.FormatInt(value, 10)
	n := len(s)
	if n <= 3 {
		return sign + s
	}

	var b strings.Builder
	b.WriteString(sign)
	for i, ch := range s {
		if i > 0 && (n-i)%3 == 0 {
			b.WriteRune(',')
		}
		b.WriteRune(ch)
	}
	return b.String()
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "Usage: go run prime_counter.go <input_file>")
		return
	}

	filePath := os.Args[1]
	if _, err := os.Stat(filePath); err != nil {
		fmt.Fprintf(os.Stderr, "Error: File not found -> %s\n", filePath)
		return
	}

	inputData, err := readNumbers(filePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: Unable to read file -> %v\n", err)
		return
	}

	numbers := inputData.Numbers
	workers := determineWorkerCount(len(numbers), runtime.NumCPU())

	singleStart := time.Now()
	singleCount := countPrimesSingleThreaded(numbers)
	singleMs := float64(time.Since(singleStart).Nanoseconds()) / 1_000_000.0

	multiStart := time.Now()
	multiCount := countPrimesMultiThreaded(numbers, workers)
	multiMs := float64(time.Since(multiStart).Nanoseconds()) / 1_000_000.0

	speedup := 0.0
	if multiMs > 0.0 {
		speedup = singleMs / multiMs
	}

	fmt.Printf("File: %s (%s numbers)\n", filepath.Base(filePath), formatWithCommas(int64(len(numbers))))
	fmt.Printf("Skipped invalid lines: %s\n\n", formatWithCommas(int64(inputData.InvalidLines)))

	fmt.Println("[Single-Threaded]")
	fmt.Printf("  Primes found: %s\n", formatWithCommas(singleCount))
	fmt.Printf("  Time: %.3f ms\n\n", singleMs)

	fmt.Printf("[Multi-Threaded] (%d threads)\n", workers)
	fmt.Printf("  Primes found: %s\n", formatWithCommas(multiCount))
	fmt.Printf("  Time: %.3f ms\n\n", multiMs)

	fmt.Printf("Speedup: %.2fx\n", speedup)
	if singleCount != multiCount {
		fmt.Println("WARNING: Single-threaded and multi-threaded counts do not match.")
	}
}
