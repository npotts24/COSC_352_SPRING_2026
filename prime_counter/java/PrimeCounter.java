import java.io.*;
import java.nio.file.*;
import java.text.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

public class PrimeCounter {
    private static final int DEFAULT_THREADS = Runtime.getRuntime().availableProcessors();

    /**
     * Efficient primality check using trial division.
     * After checking 2 and 3, only tests divisors of the form 6k±1 up to sqrt(n).
     */
    private static boolean isPrime(long n) {
        if (n < 2) return false;
        if (n == 2) return true;
        if (n % 2 == 0) return false;
        if (n == 3) return true;
        if (n % 3 == 0) return false;

        long sqrtN = (long) Math.sqrt(n);
        for (long i = 5; i <= sqrtN; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * Single-threaded approach: sequentially check all numbers for primality.
     */
    private static long singleThreadedCount(List<Long> numbers) {
        long count = 0;
        for (long num : numbers) {
            if (isPrime(num)) {
                count++;
            }
        }
        return count;
    }

    /**
     * Multi-threaded approach: distribute work across multiple threads using ExecutorService.
     */
    private static long multiThreadedCount(List<Long> numbers, int numThreads)
            throws InterruptedException {
        ExecutorService executor = Executors.newFixedThreadPool(numThreads);
        int chunkSize = (numbers.size() + numThreads - 1) / numThreads;

        List<Future<Long>> futures = new ArrayList<>();

        for (int i = 0; i < numThreads; i++) {
            int start = i * chunkSize;
            int end = Math.min(start + chunkSize, numbers.size());

            if (start >= numbers.size()) break;

            final int startIdx = start;
            final int endIdx = end;

            futures.add(executor.submit(() -> {
                long count = 0;
                for (int j = startIdx; j < endIdx; j++) {
                    if (isPrime(numbers.get(j))) {
                        count++;
                    }
                }
                return count;
            }));
        }

        long totalCount = 0;
        for (Future<Long> future : futures) {
            totalCount += future.get();
        }

        executor.shutdown();
        return totalCount;
    }

    /**
     * Read integers from file, one per line. Skip invalid or blank lines.
     */
    private static List<Long> readNumbers(String filePath) throws IOException {
        List<Long> numbers = new ArrayList<>();
        try (BufferedReader reader = Files.newBufferedReader(Paths.get(filePath))) {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;

                try {
                    long num = Long.parseLong(line);
                    numbers.add(num);
                } catch (NumberFormatException e) {
                    // Skip invalid lines
                }
            }
        }
        return numbers;
    }

    /**
     * Format large numbers with thousand separators.
     */
    private static String formatNumber(long num) {
        return String.format("%,d", num);
    }

    public static void main(String[] args) {
        if (args.length == 0) {
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

        if (numbers.isEmpty()) {
            System.err.println("No valid numbers found in file.");
            System.exit(1);
            return;
        }

        File file = new File(filePath);
        long fileSize = file.length();
        System.out.printf("File: %s (%s numbers, %s bytes)%n%n",
                file.getName(), formatNumber(numbers.size()), formatNumber(fileSize));

        // Single-threaded approach
        long startTime = System.nanoTime();
        long primeCountSingle = singleThreadedCount(numbers);
        long elapsedNanoSingle = System.nanoTime() - startTime;
        double elapsedMsSingle = elapsedNanoSingle / 1_000_000.0;

        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + formatNumber(primeCountSingle));
        System.out.printf("  Time: %.1f ms%n%n", elapsedMsSingle);

        // Multi-threaded approach
        startTime = System.nanoTime();
        long primeCountMulti = 0;
        try {
            primeCountMulti = multiThreadedCount(numbers, DEFAULT_THREADS);
        } catch (InterruptedException e) {
            System.err.println("Thread interrupted: " + e.getMessage());
            System.exit(1);
        }
        long elapsedNanoMulti = System.nanoTime() - startTime;
        double elapsedMsMulti = elapsedNanoMulti / 1_000_000.0;

        System.out.printf("[Multi-Threaded] (%d threads)%n", DEFAULT_THREADS);
        System.out.println("  Primes found: " + formatNumber(primeCountMulti));
        System.out.printf("  Time: %.1f ms%n%n", elapsedMsMulti);

        // Calculate and display speedup
        double speedup = elapsedMsSingle / elapsedMsMulti;
        System.out.printf("Speedup: %.2f x%n", speedup);

        // Verify both approaches found the same count
        if (primeCountSingle != primeCountMulti) {
            System.err.printf("Error: Single-threaded (%d) and multi-threaded (%d) counts differ!%n",
                    primeCountSingle, primeCountMulti);
            System.exit(1);
        }
    }
}
