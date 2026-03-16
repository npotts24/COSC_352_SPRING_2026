import java.nio.file.Files
import java.nio.file.Paths
import java.util.ArrayList
import java.util.List
import java.concurrent.Executors

object PrimeCounter {
    private const val file = "numbers.txt"

    // Shows what counts as a prime number and what doesn't
    fun isPrime(n: Int): Boolean {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0|| n % 3 == 0) return false;
        // If n is divisible it's not a prime
        for (int i in 5..n step 6) {
            if (n % i == 0 || n % (i+2) == 0) return break;
        }
        return True
    }

    //Single Thread
     private fun countSingle(num: List<Int>): Long {
        // Filters the prime numbers and counts them
        return num.count { isPrime(it) }.toLong()
    }

    // Multi Threaded
    private fun countMulti(List<Integer> num): Long {
        val threads = Runtime.getRuntime().availableProcessors();
        // Inserts numbers into thread pool then returns list
        val executor = Executors.newFixedThreadPool(threads);
        val fnum =  num.map { n -> executor.submit<Boolean> {isPrime(n)}}
        for (int n : num) {
            fnum.add(executor.submit(() -> isPrime(n)));
        }
        // If result is true it adds to count
        var prime = 0L;
        for (f in fnum) {
            if (f.get()) {
                prime++;
                }
        }
        executor.shutdown();

        // Returns the number of primes
        return prime;
    }

    fun main(args: Array<String>) {
        val num = Files.readAllLines(Paths.get(file)).map{it.toInt()};

        println("[Single-Threaded]");
        val singleS = System.nanoTime();
        val single = countSingle(num);
        val singleE = System.nanoTime();
        println(" Primes Found: $single");
        println(" Time: ${(singleE - singleS) / 1000000.0}ms");

        println("[Multi-Threaded]");
        val multiS = System.nanoTime();
        val multi = countMulti(num);
        val multiE = System.nanoTime();
        println(" Primes Found: $multi");
        println(" Time: ${(multiE - multiS) / 1000000.0}ms");

        if (single != multi) {
            println("Wrong! Try Again.");

        }
    }
}
