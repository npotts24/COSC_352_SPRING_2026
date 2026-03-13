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

func readNumbers(path string) ([]int64, error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer f.Close()
    scanner := bufio.NewScanner(f)
    var nums []int64
    for scanner.Scan() {
        line := scanner.Text()
        if line == "" {
            continue
        }
        v, err := strconv.ParseInt(line, 10, 64)
        if err != nil {
            continue
        }
        nums = append(nums, v)
    }
    if err := scanner.Err(); err != nil {
        return nil, err
    }
    return nums, nil
}

func main() {
    if len(os.Args) < 2 {
        fmt.Println("Usage: primes_go <file>")
        os.Exit(1)
    }
    path := os.Args[1]
    nums, err := readNumbers(path)
    if err != nil {
        fmt.Printf("Failed to read file: %v\n", err)
        os.Exit(1)
    }

    fmt.Printf("File: %s (%d numbers)\n\n", path, len(nums))

    // Single-threaded
    start := time.Now()
    var singleCount int64 = 0
    for _, v := range nums {
        if isPrime(v) {
            singleCount++
        }
    }
    singleElapsed := time.Since(start)

    fmt.Println("[Single-Threaded]")
    fmt.Printf("  Primes found: %d\n", singleCount)
    fmt.Printf("  Time: %.3f ms\n\n", float64(singleElapsed.Nanoseconds())/1e6)

    // Multi-threaded
    workers := runtime.NumCPU()
    chunk := (len(nums) + workers - 1) / workers
    var wg sync.WaitGroup
    var total int64 = 0

    start = time.Now()
    for i := 0; i < workers; i++ {
        lo := i * chunk
        hi := lo + chunk
        if lo >= len(nums) {
            break
        }
        if hi > len(nums) {
            hi = len(nums)
        }
        wg.Add(1)
        go func(slice []int64) {
            defer wg.Done()
            var local int64 = 0
            for _, v := range slice {
                if isPrime(v) {
                    local++
                }
            }
            atomic.AddInt64(&total, local)
        }(nums[lo:hi])
    }
    wg.Wait()
    multiElapsed := time.Since(start)

    fmt.Printf("[Multi-Threaded] (%d threads)\n", workers)
    fmt.Printf("  Primes found: %d\n", total)
    fmt.Printf("  Time: %.3f ms\n\n", float64(multiElapsed.Nanoseconds())/1e6)

    speedup := float64(singleElapsed.Nanoseconds()) / float64(multiElapsed.Nanoseconds())
    fmt.Printf("Speedup: %.2fx\n", speedup)
}
