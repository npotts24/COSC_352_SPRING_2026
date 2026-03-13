import java.util.*;
import java.io.*;
import java.util.concurrent.*;

public class PrimeCounter {
    public static boolean isPrime(int n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        for (int i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.out.println("Usage: java PrimeCounter <filename>");
            return;
        }

        List<Integer> nums = new ArrayList<>();
        try (Scanner sc = new Scanner(new File(args[1]))) {
            while (sc.hasNextInt()) nums.add(sc.nextInt());
        }

        // Single-Threaded
        long start = System.nanoTime();
        long countST = nums.stream().filter(PrimeCounter::isPrime).count();
        double timeST = (System.nanoTime() - start) / 1_000_000.0;

        // Multi-Threaded
        int cores = Runtime.getRuntime().availableProcessors();
        ExecutorService executor = Executors.newFixedThreadPool(cores);
        int chunkSize = (nums.size() + cores - 1) / cores;
        List<Future<Integer>> results = new ArrayList<>();

        start = System.nanoTime();
        for (int i = 0; i < cores; i++) {
            final int startIdx = i * chunkSize;
            final int endIdx = Math.min(startIdx + chunkSize, nums.size());
            results.add(executor.submit(() -> {
                int count = 0;
                for (int j = startIdx; j < endIdx; j++) {
                    if (isPrime(nums.get(j))) count++;
                }
                return count;
            }));
        }

        int countMT = 0;
        for (Future<Integer> f : results) countMT += f.get();
        double timeMT = (System.nanoTime() - start) / 1_000_000.0;
        executor.shutdown();

        System.out.printf("[Single-Threaded]\n  Primes: %d\n  Time: %.2f ms\n", countST, timeST);
        System.out.printf("[Multi-Threaded] (%d threads)\n  Primes: %d\n  Time: %.2f ms\n", cores, countMT, timeMT);
    }
}