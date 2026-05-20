import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    // Efficient primality test using 6k ± 1 optimization
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

    public static List<Long> readNumbers(String filePath) throws IOException {
        List<Long> numbers = new ArrayList<>();
        List<String> lines = Files.readAllLines(Paths.get(filePath));

        for (String line : lines) {
            line = line.trim();
            if (line.isEmpty()) continue;
            try {
                numbers.add(Long.parseLong(line));
            } catch (NumberFormatException ignored) {
            }
        }
        return numbers;
    }

    public static long singleThreaded(List<Long> numbers) {
        long count = 0;
        for (long n : numbers) {
            if (isPrime(n)) count++;
        }
        return count;
    }

    public static long multiThreaded(List<Long> numbers, int numThreads) throws InterruptedException {
        ExecutorService executor = Executors.newFixedThreadPool(numThreads);
        List<Future<Long>> futures = new ArrayList<>();

        int chunkSize = numbers.size() / numThreads;
        for (int i = 0; i < numThreads; i++) {
            int start = i * chunkSize;
            int end = (i == numThreads - 1) ? numbers.size() : start + chunkSize;

            List<Long> subList = numbers.subList(start, end);

            futures.add(executor.submit(() -> {
                long localCount = 0;
                for (long n : subList) {
                    if (isPrime(n)) localCount++;
                }
                return localCount;
            }));
        }

        long total = 0;
        for (Future<Long> f : futures) {
            try {
                total += f.get();
            } catch (ExecutionException e) {
                e.printStackTrace();
            }
        }

        executor.shutdown();
        return total;
    }

    public static void main(String[] args) throws Exception {

        if (args.length != 1) {
            System.out.println("Usage: java PrimeCounter <input_file>");
            return;
        }

        String filePath = args[0];
        List<Long> numbers;

        try {
            numbers = readNumbers(filePath);
        } catch (IOException e) {
            System.out.println("Error reading file: " + filePath);
            return;
        }

        System.out.println("File: " + filePath + " (" + numbers.size() + " numbers)");

        // Single-threaded
        long start = System.nanoTime();
        long singleCount = singleThreaded(numbers);
        long singleTime = System.nanoTime() - start;

        // Multi-threaded
        int numThreads = Runtime.getRuntime().availableProcessors();
        start = System.nanoTime();
        long multiCount = multiThreaded(numbers, numThreads);
        long multiTime = System.nanoTime() - start;

        System.out.println("\n[Single-Threaded]");
        System.out.println("  Primes found: " + singleCount);
        System.out.println("  Time: " + (singleTime / 1_000_000.0) + " ms");

        System.out.println("\n[Multi-Threaded] (" + numThreads + " threads)");
        System.out.println("  Primes found: " + multiCount);
        System.out.println("  Time: " + (multiTime / 1_000_000.0) + " ms");

        if (singleTime > 0) {
            System.out.println("\nSpeedup: " + String.format("%.2f", (double) singleTime / multiTime) + "x");
        }
    }
}
