import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public class java_prime {

    public static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java Java_prime");
            return;
        }
        List<Long> numbers = new ArrayList<>();
        try (Scanner sc = new Scanner(new File(args[0]))) {
            while (sc.hasNextLong()) {
                numbers.add(sc.nextLong());
            }
        } catch (FileNotFoundException e) {
            System.err.println("File not found");
            return;
        }

        //Single-thread
        long startS = System.nanoTime();
        long countS = 0;
        for (long n : numbers) {
            if (isPrime(n)) countS++;
        }
        long endS = System.nanoTime();
        double timeS = (endS - startS) / 1_000_000.0;

        //Multi-thread
        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<Long>> results = new ArrayList<>();
        int chunkSize = (int) Math.ceil((double) numbers.size() / threads);
        
        long startM = System.nanoTime();
        for (int i = 0; i < threads; i++) {
            final int start = i * chunkSize;
            final int end = Math.min(start + chunkSize, numbers.size());

            results.add(executor.submit(() ->{
                long localCount = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) localCount++;
                }
                return localCount;
            }));
        }

        long countM = 0;
        for (Future<Long> f : results) {
            try { countM += f.get();} catch (Exception e) {}
        }
        executor.shutdown();
        long endM = System.nanoTime();
        double timeM = (endM - startM) / 1_000_000.0;

        //results
    System.out.println("[Single-Threaded]");
    System.out.println("Primes Found: " + countS);
    System.out.printf("Time: %.1f ms\n", timeS);

    System.out.println("[Multi-Treaded] (" + threads + " threads)");
    System.out.println("Primes Found: " + countM);
    System.out.printf("Time: %.1f ms\n", timeM);

    System.out.printf("\nSpeedup: %.2fx\n" , timeS / timeM);
    }
}