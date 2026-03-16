import (
	"bufio"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"sync"
	"time"
)

func isPrime(x int64) bool {
	if x <=1 {
		return false
	}
	if x <=3 {
		return true
	}
	if x%2 == 0 || x%3 == 0 {
		return false
	}
	for i := int64(5); i*i <= x; i += 6 {
		if x%i == 0 || x%(i+2) == 0 {
			return false
		}
	}
	return true
}

func readNumbers(path string) ([]int64, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	var numbers []int64
	for scanner.Scan() {
		n, err := strconv.ParseInt(scanner.Text(), 10, 64)
		if err != nil {
			return nil, err
		}
		numbers = append(numbers, n)
	}
	return numbers, scanner.Err()
}