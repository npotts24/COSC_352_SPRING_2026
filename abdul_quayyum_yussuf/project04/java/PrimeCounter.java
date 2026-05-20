import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class PrimeCounter {
    public static void main(String[] args) {
        if (args.length == 0) {
            System.out.println("Usage: java PrimeCounter <file_path>");
            System.exit(1);
        }
        String filePath = args[0];
        List<Long> numbers = readNumbers(filePath);
        if (numbers.isEmpty()) {
            System.out.println("No valid numbers found in file.");
            System.exit(1);
        }

        System.out.println("File: " + filePath + " (" + numbers.size() + " numbers)");

        // Single-threaded
        long start = System.nanoTime();
        long singleCount = countPrimesSingle(numbers);
        long end = System.nanoTime();
        double singleTime = (end - start) / 1_000_000.0;

        System.out.println("\n[Single-Threaded]");
        System.out.printf("  Primes found: %,d\n", singleCount);
        System.out.printf("  Time: %.1f ms\n", singleTime);

        // Multi-threaded
        int cores = Runtime.getRuntime().availableProcessors();
        start = System.nanoTime();
        long multiCount = countPrimesMulti(numbers, cores);
        end = System.nanoTime();
        double multiTime = (end - start) / 1_000_000.0;

        System.out.println("\n[Multi-Threaded] (" + cores + " threads)");
        System.out.printf("  Primes found: %,d\n", multiCount);
        System.out.printf("  Time: %.1f ms\n", multiTime);

        double speedup = singleTime / multiTime;
        System.out.printf("Speedup: %.2fx\n", speedup);
    }

    private static List<Long> readNumbers(String filePath) {
        List<Long> numbers = new ArrayList<>();
        try {
            List<String> lines = Files.readAllLines(Paths.get(filePath));
            for (String line : lines) {
                String trimmed = line.trim();
                if (!trimmed.isEmpty()) {
                    try {
                        long num = Long.parseLong(trimmed);
                        if (num > 1) {
                            numbers.add(num);
                        }
                    } catch (NumberFormatException e) {
                        // Skip invalid lines
                    }
                }
            }
        } catch (IOException e) {
            System.out.println("Error reading file: " + e.getMessage());
            System.exit(1);
        }
        return numbers;
    }

    private static long countPrimesSingle(List<Long> numbers) {
        long count = 0;
        for (long num : numbers) {
            if (isPrime(num)) {
                count++;
            }
        }
        return count;
    }

    private static long countPrimesMulti(List<Long> numbers, int numThreads) {
        ExecutorService executor = Executors.newFixedThreadPool(numThreads);
        List<Future<Long>> futures = new ArrayList<>();
        int chunkSize = numbers.size() / numThreads;
        int remainder = numbers.size() % numThreads;

        int start = 0;
        for (int i = 0; i < numThreads; i++) {
            int end = start + chunkSize + (i < remainder ? 1 : 0);
            List<Long> chunk = numbers.subList(start, end);
            futures.add(executor.submit(new PrimeCounterTask(chunk)));
            start = end;
        }

        long totalCount = 0;
        try {
            for (Future<Long> future : futures) {
                totalCount += future.get();
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            executor.shutdown();
        }
        return totalCount;
    }

    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    static class PrimeCounterTask implements Callable<Long> {
        private final List<Long> numbers;

        public PrimeCounterTask(List<Long> numbers) {
            this.numbers = numbers;
        }

        @Override
        public Long call() {
            long count = 0;
            for (long num : numbers) {
                if (isPrime(num)) {
                    count++;
                }
            }
            return count;
        }
    }
}