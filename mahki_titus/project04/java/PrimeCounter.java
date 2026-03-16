import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.out.println("Usage: java PrimeCounter <file>");
            return;
        }

        List<Long> numbers = readNumbers(args[0]);
        if (numbers.isEmpty()) {
            System.out.println("No valid numbers found.");
            return;
        }

        System.out.printf("File: %s (%d numbers)%n%n", args[0], numbers.size());

        // Single-threaded
        long startSingle = System.nanoTime();
        long singleCount = countPrimesSequential(numbers);
        long endSingle = System.nanoTime();
        double singleTime = (endSingle - startSingle) / 1_000_000.0;

        // Multi-threaded
        int threads = Runtime.getRuntime().availableProcessors();
        long startMulti = System.nanoTime();
        long multiCount = countPrimesParallel(numbers, threads);
        long endMulti = System.nanoTime();
        double multiTime = (endMulti - startMulti) / 1_000_000.0;

        printResults("Single-Threaded", singleCount, singleTime);
        printResults("Multi-Threaded (" + threads + " threads)", multiCount, multiTime);

        System.out.printf("%nSpeedup: %.2fx%n", singleTime / multiTime);
    }

    private static List<Long> readNumbers(String path) throws IOException {
        List<Long> numbers = new ArrayList<>();
        for (String line : Files.readAllLines(Paths.get(path))) {
            try {
                if (!line.trim().isEmpty())
                    numbers.add(Long.parseLong(line.trim()));
            } catch (NumberFormatException ignored) {}
        }
        return numbers;
    }

    private static long countPrimesSequential(List<Long> numbers) {
        long count = 0;
        for (long n : numbers) {
            if (isPrime(n)) count++;
        }
        return count;
    }

    private static long countPrimesParallel(List<Long> numbers, int threads) throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<Long>> futures = new ArrayList<>();

        int chunkSize = numbers.size() / threads;

        for (int i = 0; i < threads; i++) {
            int start = i * chunkSize;
            int end = (i == threads - 1) ? numbers.size() : start + chunkSize;

            futures.add(executor.submit(() -> {
                long count = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) count++;
                }
                return count;
            }));
        }

        long total = 0;
        for (Future<Long> f : futures)
            total += f.get();

        executor.shutdown();
        return total;
    }

    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0)
                return false;
        }
        return true;
    }

    private static void printResults(String label, long count, double time) {
        System.out.printf("[%s]%n", label);
        System.out.printf("  Primes found: %,d%n", count);
        System.out.printf("  Time: %.2f ms%n%n", time);
    }
}