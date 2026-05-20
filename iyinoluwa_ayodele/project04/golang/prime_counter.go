package main

import (
    "bufio"
    "fmt"
    "math"
    "os"
    "runtime"
    "strconv"
    "sync"
    "sync/atomic"
    "time"
)

func main() {
    if len(os.Args) < 2 {
        fmt.Println("Usage: go run prime_counter.go <numbers-file>")
        return
    }
    path := os.Args[1]
    file, err := os.Open(path)
    if err != nil {
        fmt.Printf("Cannot open file: %v\n", err)
        return
    }
    defer file.Close()

    var numbers []int64
    scanner := bufio.NewScanner(file)
    for scanner.Scan() {
        line := scanner.Text()
        if len(line) == 0 {
            continue
        }
        v, err := strconv.ParseInt(line, 10, 64)
        if err != nil {
            continue
        }
        numbers = append(numbers, v)
    }

    fmt.Printf("File: %s (%d numbers)\n\n", path, len(numbers))

    // Single-threaded
    start := time.Now()
    var singleCount int64 = 0
    for _, v := range numbers {
        if isPrime(v) {
            singleCount++
        }
    }
    singleMs := time.Since(start).Milliseconds()
    fmt.Println("[Single-Threaded]")
    fmt.Printf("  Primes found: %d\n", singleCount)
    fmt.Printf("  Time: %d ms\n\n", singleMs)

    // Multi-threaded
    threads := runtime.NumCPU()
    var total int64 = 0
    var wg sync.WaitGroup
    n := len(numbers)
    if n > 0 {
        chunk := (n + threads - 1) / threads
        pstart := time.Now()
        for i := 0; i < n; i += chunk {
            lo := i
            hi := i + chunk
            if hi > n {
                hi = n
            }
            wg.Add(1)
            go func(lo, hi int) {
                defer wg.Done()
                var local int64 = 0
                for j := lo; j < hi; j++ {
                    if isPrime(numbers[j]) {
                        local++
                    }
                }
                atomic.AddInt64(&total, local)
            }(lo, hi)
        }
        wg.Wait()
        pMs := time.Since(pstart).Milliseconds()
        fmt.Printf("[Multi-Threaded] (%d threads)\n", threads)
        fmt.Printf("  Primes found: %d\n", total)
        fmt.Printf("  Time: %d ms\n\n", pMs)
        speedup := float64(singleMs) / math.Max(1.0, float64(pMs))
        fmt.Printf("Speedup: %.2fx\n", speedup)
    } else {
        fmt.Println("No numbers to process.")
    }
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
    var i int64 = 5
    for i*i <= n {
        if n%i == 0 || n%(i+2) == 0 {
            return false
        }
        i += 6
    }
    return true
}
