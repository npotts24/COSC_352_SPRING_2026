import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    public static boolean isPrime(int n) {
        if (n < 2) return false;
        if (n == 2) return true;
        if (n % 2 == 0) return false;

        for (int i = 3; i * i <= n; i += 2) {
            if (n % i == 0) return false;
        }
        return true;
    }

    public static List<Integer> readNumbers(String filename) throws IOException {
        List<Integer> numbers = new ArrayList<>();
        for (String line : Files.readAllLines(Paths.get(filename))) {
            numbers.add(Integer.parseInt(line.trim()));
        }
        return numbers;
    }

    public static int singleThread(List<Integer> numbers) {
        int count = 0;
        for (int n : numbers) {
            if (isPrime(n)) count++;
        }
        return count;
    }

    public static int multiThread(List<Integer> numbers, int threads) throws InterruptedException {
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<Integer>> futures = new ArrayList<>();

        int chunkSize = numbers.size() / threads;

        for (int i = 0; i < threads; i++) {
            int start = i * chunkSize;
            int end = (i == threads - 1) ? numbers.size() : start + chunkSize;

            futures.add(executor.submit(() -> {
                int localCount = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) localCount++;
                }
                return localCount;
            }));
        }

        int total = 0;
        for (Future<Integer> f : futures) {
            try {
                total += f.get();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        executor.shutdown();
        return total;
    }

    public static void main(String[] args) throws Exception {
        String filename = "testdata/numbers.txt";
        List<Integer> numbers = readNumbers(filename);
        int threads = Runtime.getRuntime().availableProcessors();

        System.out.println("File: " + filename + " (" + numbers.size() + " numbers)");
        System.out.println("CPU Cores Available: " + threads);
        System.out.println();

        long start = System.nanoTime();
        int singleCount = singleThread(numbers);
        long singleTime = System.nanoTime() - start;

        System.out.println("[Single-Threaded]");
        System.out.printf("  Primes found: %,d\n", singleCount);
        System.out.printf("  Time: %.2f ms\n\n", singleTime / 1_000_000.0);

        start = System.nanoTime();
        int multiCount = multiThread(numbers, threads);
        long multiTime = System.nanoTime() - start;

        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.printf("  Primes found: %,d\n", multiCount);
        System.out.printf("  Time: %.2f ms\n\n", multiTime / 1_000_000.0);

        double speedup = (double) singleTime / multiTime;
        System.out.printf("Speedup: %.2fx\n", speedup);
    }
}
