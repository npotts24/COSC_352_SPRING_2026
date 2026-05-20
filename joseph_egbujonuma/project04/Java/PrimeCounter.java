import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.text.DecimalFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class PrimeCounter {

    // Efficient trial division: 6k ± 1
    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    // Read all numbers BEFORE timing
    private static long[] readNumbers(String path) throws IOException {
        List<Long> list = new ArrayList<>(1_000_000);
        File file = new File(path);

        try (BufferedReader br = new BufferedReader(new FileReader(file))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;

                try {
                    list.add(Long.parseLong(line));
                } catch (NumberFormatException ignored) {
                    // skip invalid lines gracefully
                }
            }
        }

        long[] arr = new long[list.size()];
        for (int i = 0; i < list.size(); i++) {
            arr[i] = list.get(i);
        }
        return arr;
    }

    private static int countPrimesSingle(long[] nums) {
        int count = 0;
        for (long v : nums) {
            if (isPrime(v)) count++;
        }
        return count;
    }

    private static int countPrimesMulti(long[] nums, int threads) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        try {
            int n = nums.length;
            int chunkSize = (n + threads - 1) / threads;

            List<Callable<Integer>> tasks = new ArrayList<>();

            for (int start = 0; start < n; start += chunkSize) {
                int s = start;
                int e = Math.min(start + chunkSize, n);

                tasks.add(() -> {
                    int local = 0;
                    for (int i = s; i < e; i++) {
                        if (isPrime(nums[i])) local++;
                    }
                    return local;
                });
            }

            List<Future<Integer>> futures = pool.invokeAll(tasks);

            int total = 0;
            for (Future<Integer> f : futures) {
                total += f.get();
            }
            return total;
        } finally {
            pool.shutdown();
        }
    }

    private static void usage() {
        System.out.println("Usage: java PrimeCounter <path-to-numbers.txt>");
    }

    public static void main(String[] args) {
        if (args.length == 0) {
            usage();
            return;
        }

        String path = args[0];
        File file = new File(path);
        if (!file.exists() || !file.canRead()) {
            System.out.println("Cannot read file: " + path);
            usage();
            return;
        }

        try {
            // File I/O before timing
            long[] nums = readNumbers(path);
            int threads = Runtime.getRuntime().availableProcessors();

            // Single-threaded timing
            long sStart = System.nanoTime();
            int singleCount = countPrimesSingle(nums);
            double singleMs = (System.nanoTime() - sStart) / 1_000_000.0;

            // Multi-threaded timing
            long mStart = System.nanoTime();
            int multiCount = countPrimesMulti(nums, threads);
            double multiMs = (System.nanoTime() - mStart) / 1_000_000.0;

            DecimalFormat dfCount = new DecimalFormat("#,##0");
            DecimalFormat dfTime = new DecimalFormat("#0.0");
            DecimalFormat dfSpeed = new DecimalFormat("#0.00");

            double speedup = singleMs / multiMs;

            System.out.println("File: " + file.getName() +
                    " (" + dfCount.format(nums.length) + " numbers)\n");

            System.out.println("[Single-Threaded]");
            System.out.println("  Primes found: " + dfCount.format(singleCount));
            System.out.println("  Time: " + dfTime.format(singleMs) + " ms\n");

            System.out.println("[Multi-Threaded] (" + threads + " threads)");
            System.out.println("  Primes found: " + dfCount.format(multiCount));
            System.out.println("  Time: " + dfTime.format(multiMs) + " ms\n");

            if (singleCount != multiCount) {
                System.out.println("WARNING: Counts differ!");
            }

            System.out.println("Speedup: " + dfSpeed.format(speedup) + "x");

        } catch (Exception e) {
            System.out.println("Error: " + e.getMessage());
        }
    }
}
