import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.*;

public class PrimeCounter {

    // Efficient trial division: check 2,3 then 6k±1 up to sqrt(n)
    static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        for (long i = 5; i <= n / i; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    static List<Long> readAllNumbers(Path file) throws IOException {
        List<Long> nums = new ArrayList<>(1024);
        try (BufferedReader br = Files.newBufferedReader(file)) {
            String line;
            while ((line = br.readLine()) != null) {
                String s = line.trim();
                if (s.isEmpty()) continue;
                try {
                    nums.add(Long.parseLong(s));
                } catch (NumberFormatException ignored) {
                    // skip invalid line gracefully
                }
            }
        }
        return nums;
    }

    static long countSingle(List<Long> nums) {
        long count = 0;
        for (long x : nums) if (isPrime(x)) count++;
        return count;
    }

    static long countParallel(List<Long> nums, int threads) throws ExecutionException, InterruptedException {
        int n = nums.size();
        if (n == 0) return 0;

        int t = Math.max(1, threads);
        t = Math.min(t, n);

        ExecutorService pool = Executors.newFixedThreadPool(t);
        try {
            int chunk = (n + t - 1) / t;
            List<Future<Long>> futures = new ArrayList<>(t);

            for (int i = 0; i < t; i++) {
                final int start = i * chunk;
                final int end = Math.min(n, start + chunk);
                if (start >= end) break;

                futures.add(pool.submit(() -> {
                    long local = 0;
                    for (int idx = start; idx < end; idx++) {
                        if (isPrime(nums.get(idx))) local++;
                    }
                    return local;
                }));
            }

            long total = 0;
            for (Future<Long> f : futures) total += f.get();
            return total;
        } finally {
            pool.shutdown();
        }
    }

    static void usage() {
        System.out.println("Usage: java PrimeCounter <path/to/numbers.txt>");
    }

    public static void main(String[] args) {
        Locale.setDefault(Locale.US);

        if (args.length < 1) {
            usage();
            System.exit(1);
        }

        Path file = Path.of(args[0]);
        if (!Files.isReadable(file)) {
            System.out.println("Error: cannot read file: " + file);
            usage();
            System.exit(1);
        }

        final List<Long> nums;
        try {
            nums = readAllNumbers(file); // I/O done BEFORE timing
        } catch (IOException e) {
            System.out.println("Error reading file: " + e.getMessage());
            System.exit(1);
            return;
        }

        int threads = Runtime.getRuntime().availableProcessors();

        System.out.printf("File: %s (%d numbers)%n%n", file.getFileName(), nums.size());

        long t1 = System.nanoTime();
        long single = countSingle(nums);
        long t2 = System.nanoTime();
        double singleMs = (t2 - t1) / 1_000_000.0;

        System.out.println("[Single-Threaded]");
        System.out.printf("  Primes found: %,d%n", single);
        System.out.printf("  Time: %.3f ms%n%n", singleMs);

        long multi;
        long t3 = System.nanoTime();
        try {
            multi = countParallel(nums, threads);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            System.out.println("Error: parallel execution interrupted.");
            System.exit(1);
            return;
        } catch (ExecutionException e) {
            System.out.println("Error: parallel execution failed: " + e.getCause());
            System.exit(1);
            return;
        }
        long t4 = System.nanoTime();
        double multiMs = (t4 - t3) / 1_000_000.0;

        System.out.printf("[Multi-Threaded] (%d threads)%n", threads);
        System.out.printf("  Primes found: %,d%n", multi);
        System.out.printf("  Time: %.3f ms%n%n", multiMs);

        if (single != multi) {
            System.out.printf("WARNING: Counts do not match! single=%d multi=%d%n", single, multi);
        }

        double speedup = (multiMs > 0) ? (singleMs / multiMs) : Double.POSITIVE_INFINITY;
        System.out.printf("Speedup: %.2fx%n", speedup);
    }
}
