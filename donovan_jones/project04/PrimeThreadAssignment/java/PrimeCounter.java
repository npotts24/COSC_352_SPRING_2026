import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    static boolean isPrime(long n) {
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

        long start = System.nanoTime();
        long count = numbers.stream().filter(PrimeCounter::isPrime).count();
        long singleTime = System.nanoTime() - start;

        System.out.println("\n[Single-Threaded]");
        System.out.println("Primes found: " + count);
        System.out.println("Time: " + singleTime / 1_000_000.0 + " ms");

        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        List<Future<Long>> futures = new ArrayList<>();

        int chunk = numbers.size() / threads;
        start = System.nanoTime();

        for (int i = 0; i < threads; i++) {
            int from = i * chunk;
            int to = (i == threads - 1) ? numbers.size() : from + chunk;
            futures.add(pool.submit(() -> {
                long c = 0;
                for (int j = from; j < to; j++)
                    if (isPrime(numbers.get(j))) c++;
                return c;
            }));
        }

        long multiCount = 0;
        for (Future<Long> f : futures)
            multiCount += f.get();

        pool.shutdown();
        long multiTime = System.nanoTime() - start;

        System.out.println("\n[Multi-Threaded] (" + threads + " threads)");
        System.out.println("Primes found: " + multiCount);
        System.out.println("Time: " + multiTime / 1_000_000.0 + " ms");
        System.out.println("\nSpeedup: " + (double)singleTime / multiTime + "x");
    }
}
