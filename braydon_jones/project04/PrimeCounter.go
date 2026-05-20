package main

import {
	"fmt"
	"runtime"
	"time"
}
// Checks if number is prime
func isPrime(n int) bool {
	if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
	// Establishes that if n is divisible it's not a prime
    for (int i := 5; i * i <= n; i += 6) {
		if (n % i == 0 || n % (i + 2) == 0) return false;
    }
    return true;
}

// Singke thread
func countSingle(num []int) int64 {
	var prime int64 = 0
	// Loops through numbers and says if number is prime, add to count
	for_, n := range num {
		if isPrime(n) {
			prime++;
            }
        }
		return prime
}

// Multi Thread
func countMulti(num []int) int64 {
	threads:= runtime.NumCPU()
	jobs := make(chan int, len(nums))
	prime := make (chan bool, len(nums))
	for i: = 0; i < threads; i++ {
		go func() {
			for n:= range jobs {
				resultd <- isPrime(n)
			}
		}()
	}
	// Each worker reads from job and sends result to isPrime
	for _, n:= range num {
		jobs <- n
	}
	close(jobs)

	var primeCount int64 = 0

	// Reads result and adds to count if it's true
	for i: = 0; i < threads; i++ {
		if <- prime {
			prime++;
            }
        }
		return prime
}

// Prints statements
func main(){
	num := "numbers.txt"
	    fmt.Println("[Single-Threaded]")
        singleS := time.Now()
        single := countSingle(num)
        singleE := time.Since(singleS)
        fmt.Println(" Primes Found: ", single)
        fmt.Println(" Time: ", singleE.Milliseconds(), "ms")

        fmt.Println("[Multi-Threaded]")
        multiS = time.Now()
        multi = countMulti(num)
        multiE = time.Since(multS)
    	fmt.Println(" Primes Found: ", multi)
        fmt.Println(" Time: ", multiE.Milliseconds(), "ms")

		if single != multi {
			System.out.println("Wrong! Try Again.")

        }
}