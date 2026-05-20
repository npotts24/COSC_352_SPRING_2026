//Imports
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

public class PrimeCounter {

    static String file = "numbers.txt";

    //Establishing what is and isn't a prime number
    public static boolean isPrime(int n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0|| n % 3 == 0) return false;
        for (int i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i+2) == 0) return false;
        }
        return true;
    }
    // Single Threaded
    private static long countSingle(List<Integer> num) {
        //Filters the prime numbers and counts them
        return num.stream().filter(PrimeCounter::isPrime).count();
    }

    // Multi Threaded
    private static long countMulti(List<Integer> num) throws Exception {
        int threads = Runtime.getRuntime().availableProcessors();
        //Filters the prime numbers and counts them
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<Boolean>> fnum =  new ArrayList<>();
        for (int n : num) {
            fnum.add(executor.submit(() -> isPrime(n)));
        }
        long prime = 0;
        for (Future<Boolean> f : fnum) {
            if (f.get()) {
                prime++;
                }
        }
        executor.shutdown();

        // Returns the number of primes
        return prime;
    }

    public static void main(String[] args) throws Exception {
        List<Integer> num = Files.readAllLines(Paths.get(file)).stream().map(Integer::parseInt).toList();

        System.out.println("[Single-Threaded]");
        long singleS = System.nanoTime();
        long single = countSingle(num);
        long singleE = System.nanoTime();
        System.out.println(" Primes Found: " + single);
        System.out.println(" Time: " + (singleE - singleS) / 1000000.0 + "ms");

        System.out.println("[Multi-Threaded]");
        long multiS = System.nanoTime();
        long multi = countMulti(num);
        long multiE = System.nanoTime();
        System.out.println(" Primes Found: " + multi);
        System.out.println(" Time: " + (multiE - multiS) / 1000000.0 + "ms");

        if (single != multi) {
            System.out.println("Wrong! Try Again.");

        }
    }
    
}