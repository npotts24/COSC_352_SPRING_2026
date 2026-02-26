import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    public static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0)
                return false;
        }
        return true;
    }

    public static void main(String[] args) throws Exception {

        if (args.length == 0) {
            System.out.println("Usage: java PrimeCounter <file>");
            return;
        }

        List<Long> numbers = new ArrayList<>();

        BufferedReader br = new BufferedReader(new FileReader(args[0]));
        String line;
        while ((line = br.readLine()) != null) {
            try {
                numbers.add(Long.parseLong(line.trim()));
            } catch (Exception ignored) {}
        }
        br.close();

        System.out.println("File: " + args[0] + " (" + numbers.size() + " numbers)");

        // SINGLE THREAD
        long start = System.nanoTime();
        long count = numbers.stream().filter(PrimeCounter::isPrime).count();
        long end = System.nanoTime();
        double singleTime = (end - start) / 1_000_000.0;

        System.out.println("\n[Single-Threaded]");
        System.out.println("Primes found: " + count);
        System.out.println("Time: " + singleTime + " ms");

        // MULTI THREAD
        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService executor = Executors.newFixedThreadPool(threads);

        start = System.nanoTime();

        int chunkSize = numbers.size() / threads;
        List<Future<Long>> futures = new ArrayList<>();

        for (int i = 0; i < threads; i++) {
            int startIdx = i * chunkSize;
            int endIdx = (i == threads - 1) ? numbers.size() : startIdx + chunkSize;

            futures.add(executor.submit(() -> {
                long localCount = 0;
                for (int j = startIdx; j < endIdx; j++)
                    if (isPrime(numbers.get(j)))
                        localCount++;
                return localCount;
            }));
        }

        long total = 0;
        for (Future<Long> f : futures)
            total += f.get();

        end = System.nanoTime();
        double multiTime = (end - start) / 1_000_000.0;

        executor.shutdown();

        System.out.println("\n[Multi-Threaded] (" + threads + " threads)");
        System.out.println("Primes found: " + total);
        System.out.println("Time: " + multiTime + " ms");

        System.out.println("\nSpeedup: " + (singleTime / multiTime) + "x");
    }
}
