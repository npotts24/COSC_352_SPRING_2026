import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class PrimeCounter {

    // Efficient trial division: check 2, 3 then 6k±1 up to sqrt(n)
    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true; // 2 and 3
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i <= n / i; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    private static long countPrimesSingle(long[] nums) {
        long count = 0;
        for (long x : nums) {
            if (isPrime(x)) count++;
        }
        return count;
    }

    private static long countPrimesMulti(long[] nums, int threads) {
        int n = nums.length;
        if (n == 0) return 0;

        threads = Math.max(1, Math.min(threads, n));
        int chunkSize = (n + threads - 1) / threads;

        ExecutorService pool = Executors.newFixedThreadPool(threads);
        List<Future<Long>> futures = new ArrayList<>(threads);

        for (int t = 0; t < threads; t++) {
            final int start = t * chunkSize;
            final int end = Math.min(n, start + chunkSize);
            if (start >= end) break;

            futures.add(pool.submit(new Callable<Long>() {
                @Override
                public Long call() {
                    long local = 0;
                    for (int i = start; i < end; i++) {
                        if (isPrime(nums[i])) local++;
                    }
                    return local;
                }
            }));
        }

        long total = 0;
        try {
            for (Future<Long> f : futures) {
                total += f.get();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            pool.shutdownNow();
            throw new RuntimeException("Interrupted while counting primes", e);
        } catch (ExecutionException e) {
            pool.shutdownNow();
            throw new RuntimeException("Worker failed while counting primes", e.getCause());
        } finally {
            pool.shutdown();
        }

        return total;
    }

    private static long[] readAllNumbers(String path) throws IOException {
        ArrayList<Long> list = new ArrayList<>(1024);

        try (BufferedReader br = new BufferedReader(new FileReader(path))) {
            String line;
            while ((line = br.readLine()) != null) {
                String s = line.trim();
                if (s.isEmpty()) continue;
                try {
                    long val = Long.parseLong(s);
                    list.add(val);
                } catch (NumberFormatException ignored) {
                    // Skip invalid lines gracefully
                }
            }
        }

        long[] nums = new long[list.size()];
        for (int i = 0; i < list.size(); i++) nums[i] = list.get(i);
        return nums;
    }

    private static void usage() {
        System.out.println("Usage: java PrimeCounter <path-to-numbers.txt>");
        System.out.println("  File must contain one integer per line. Invalid/blank lines are skipped.");
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            usage();
            System.exit(1);
        }

        String path = args[0];
        final long[] nums;
        try {
            nums = readAllNumbers(path);
        } catch (IOException e) {
            System.out.println("Error: Cannot read file: " + path);
            System.out.println("Details: " + e.getMessage());
            usage();
            System.exit(1);
            return;
        }

        int threads = Runtime.getRuntime().availableProcessors();

        System.out.printf("Language: Java%n");
        System.out.printf("File: %s (%d numbers)%n%n", path, nums.length);

        long t1Start = System.nanoTime();
        long singleCount = countPrimesSingle(nums);
        long t1End = System.nanoTime();
        double singleMs = (t1End - t1Start) / 1_000_000.0;

        long t2Start = System.nanoTime();
        long multiCount = countPrimesMulti(nums, threads);
        long t2End = System.nanoTime();
        double multiMs = (t2End - t2Start) / 1_000_000.0;

        System.out.println("[Single-Threaded]");
        System.out.printf("  Primes found: %,d%n", singleCount);
        System.out.printf("  Time: %.3f ms%n%n", singleMs);

        System.out.printf("[Multi-Threaded] (%d threads)%n", Math.max(1, Math.min(threads, Math.max(nums.length, 1))));
        System.out.printf("  Primes found: %,d%n", multiCount);
        System.out.printf("  Time: %.3f ms%n%n", multiMs);

        if (singleCount != multiCount) {
            System.out.println("WARNING: counts do not match! (single=" + singleCount + ", multi=" + multiCount + ")");
        }

        double speedup = (multiMs == 0.0) ? Double.POSITIVE_INFINITY : (singleMs / multiMs);
        System.out.printf("Speedup: %.2fx%n", speedup);
    }
}