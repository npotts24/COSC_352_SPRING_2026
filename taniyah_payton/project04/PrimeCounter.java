import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

public class PrimeCounter {

    /**
     * Efficient primality check using trial division.
     * Tests divisibility by 2 and 3, then checks factors of the form 6k±1
     * up to the square root of n.
     */
    static boolean isPrime(long n) {
        if (n < 2) return false;
        if (n == 2 || n == 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    /**
     * Read all valid integers from the file, skipping blank lines and non-integers.
     */
    static List<Long> readNumbers(String filePath) throws IOException {
        List<Long> numbers = new ArrayList<>();
        List<String> lines = Files.readAllLines(Path.of(filePath));
        for (String line : lines) {
            line = line.trim();
            if (line.isEmpty()) continue;
            try {
                numbers.add(Long.parseLong(line));
            } catch (NumberFormatException e) {
                // Skip invalid entries
            }
        }
        return numbers;
    }

    /**
     * Single-threaded: iterate through numbers sequentially.
     */
    static long countPrimesSingleThreaded(List<Long> numbers) {
        long count = 0;
        for (long n : numbers) {
            if (isPrime(n)) count++;
        }
        return count;
    }

    /**
     * Multi-threaded: split numbers into chunks, one per thread.
     * Uses ExecutorService with a fixed thread pool sized to available CPU cores.
     */
    static long countPrimesMultiThreaded(List<Long> numbers, int threadCount) throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        List<Future<Long>> futures = new ArrayList<>();

        // Split the list into roughly equal chunks
        int size = numbers.size();
        int chunkSize = (size + threadCount - 1) / threadCount;

        for (int i = 0; i < size; i += chunkSize) {
            final int start = i;
            final int end = Math.min(i + chunkSize, size);
            futures.add(executor.submit(() -> {
                long count = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) count++;
                }
                return count;
            }));
        }

        long total = 0;
        for (Future<Long> future : futures) {
            total += future.get();
        }
        executor.shutdown();
        return total;
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java PrimeCounter <file_path>");
            System.exit(1);
        }

        String filePath = args[0];
        List<Long> numbers;

        try {
            numbers = readNumbers(filePath);
        } catch (IOException e) {
            System.err.println("Error reading file: " + e.getMessage());
            System.exit(1);
            return;
        }

        int threadCount = Runtime.getRuntime().availableProcessors();

        System.out.printf("File: %s (%,d numbers)%n%n", filePath, numbers.size());

        // Single-threaded
        long stStart = System.nanoTime();
        long stCount = countPrimesSingleThreaded(numbers);
        long stElapsed = System.nanoTime() - stStart;

        System.out.println("[Single-Threaded]");
        System.out.printf("  Primes found: %,d%n", stCount);
        System.out.printf("  Time: %.1f ms%n%n", stElapsed / 1_000_000.0);

        // Multi-threaded
        long mtStart = System.nanoTime();
        long mtCount;
        try {
            mtCount = countPrimesMultiThreaded(numbers, threadCount);
        } catch (InterruptedException | ExecutionException e) {
            System.err.println("Error in multi-threaded execution: " + e.getMessage());
            System.exit(1);
            return;
        }
        long mtElapsed = System.nanoTime() - mtStart;

        System.out.printf("[Multi-Threaded] (%d threads)%n", threadCount);
        System.out.printf("  Primes found: %,d%n", mtCount);
        System.out.printf("  Time: %.1f ms%n%n", mtElapsed / 1_000_000.0);

        double speedup = (double) stElapsed / mtElapsed;
        System.out.printf("Speedup: %.2fx%n", speedup);
    }
}
