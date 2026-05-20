import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    public static void main(String[] args) throws Exception {

        if (args.length == 0) {
            System.out.println("Usage: java PrimeCounter <file_path>");
            return;
        }

        List<Long> numbers = readFile(args[0]);

        System.out.println("File: " + args[0] + " (" + numbers.size() + " numbers)\n");

        // Single-threaded
        long startSingle = System.nanoTime();
        long singleCount = countPrimesSingle(numbers);
        long endSingle = System.nanoTime();

        double singleTime = (endSingle - startSingle) / 1_000_000.0;

        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + singleCount);
        System.out.printf("  Time: %.2f ms\n\n", singleTime);

        // Multi-threaded
        int threads = Runtime.getRuntime().availableProcessors();
        long startMulti = System.nanoTime();
        long multiCount = countPrimesMulti(numbers, threads);
        long endMulti = System.nanoTime();

        double multiTime = (endMulti - startMulti) / 1_000_000.0;

        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.println("  Primes found: " + multiCount);
        System.out.printf("  Time: %.2f ms\n\n", multiTime);

        System.out.printf("Speedup: %.2fx\n", singleTime / multiTime);
    }

    static List<Long> readFile(String path) throws IOException {
        List<Long> numbers = new ArrayList<>();
        for (String line : Files.readAllLines(Paths.get(path))) {
            try {
                if (!line.trim().isEmpty())
                    numbers.add(Long.parseLong(line.trim()));
            } catch (NumberFormatException ignored) {}
        }
        return numbers;
    }

    static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i * i <= n; i += 6)
            if (n % i == 0 || n % (i + 2) == 0)
                return false;

        return true;
    }

    static long countPrimesSingle(List<Long> numbers) {
        long count = 0;
        for (long n : numbers)
            if (isPrime(n)) count++;
        return count;
    }

    static long countPrimesMulti(List<Long> numbers, int threads) throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<Long>> futures = new ArrayList<>();

        int chunkSize = numbers.size() / threads;

        for (int i = 0; i < threads; i++) {
            int start = i * chunkSize;
            int end = (i == threads - 1) ? numbers.size() : start + chunkSize;

            futures.add(executor.submit(() -> {
                long count = 0;
                for (int j = start; j < end; j++)
                    if (isPrime(numbers.get(j))) count++;
                return count;
            }));
        }

        long total = 0;
        for (Future<Long> f : futures)
            total += f.get();

        executor.shutdown();
        return total;
    }
}