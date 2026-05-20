import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    // Efficient primality check using 6k ± 1 method
    public static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        long limit = (long) Math.sqrt(n);
        for (long i = 5; i <= limit; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0)
                return false;
        }
        return true;
    }

    // Read all numbers before timing
    public static List<Long> readNumbers(String filePath) throws IOException {
        List<Long> numbers = new ArrayList<>();
        BufferedReader br = new BufferedReader(new FileReader(filePath));

        String line;
        while ((line = br.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) continue;

            try {
                long value = Long.parseLong(line);
                numbers.add(value);
            } catch (NumberFormatException e) {
                // Skip invalid lines gracefully
            }
        }

        br.close();
        return numbers;
    }

    // Single-threaded counting
    public static int countSingle(List<Long> numbers) {
        int count = 0;
        for (long n : numbers) {
            if (isPrime(n)) count++;
        }
        return count;
    }

    // Multi-threaded counting
    public static int countMulti(List<Long> numbers, int threads) throws InterruptedException {
        ExecutorService executor = Executors.newFixedThreadPool(threads);
        List<Future<Integer>> futures = new ArrayList<>();

        int chunkSize = numbers.size() / threads;

        for (int i = 0; i < threads; i++) {
            int start = i * chunkSize;
            int end = (i == threads - 1) ? numbers.size() : start + chunkSize;

            Callable<Integer> task = () -> {
                int localCount = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) localCount++;
                }
                return localCount;
            };

            futures.add(executor.submit(task));
        }

        int total = 0;
        for (Future<Integer> f : futures) {
            try {
                total += f.get();
            } catch (ExecutionException e) {
                e.printStackTrace();
            }
        }

        executor.shutdown();
        return total;
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java PrimeCounter <file_path>");
            System.exit(1);
        }

        String filePath = args[0];
        List<Long> numbers;

        try {
            numbers = readNumbers(filePath);
        } catch (IOException e) {
            System.out.println("Error reading file: " + e.getMessage());
            return;
        }

        System.out.println("File: " + filePath + " (" + numbers.size() + " numbers)\n");

        // Single-threaded
        long startSingle = System.nanoTime();
        int singleCount = countSingle(numbers);
        long elapsedSingle = System.nanoTime() - startSingle;

        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + singleCount);
        System.out.printf("  Time: %.3f ms\n\n", elapsedSingle / 1_000_000.0);

        // Multi-threaded
        int threads = Runtime.getRuntime().availableProcessors();

        long startMulti = System.nanoTime();
        int multiCount;
        try {
            multiCount = countMulti(numbers, threads);
        } catch (InterruptedException e) {
            System.out.println("Thread interrupted.");
            return;
        }
        long elapsedMulti = System.nanoTime() - startMulti;

        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.println("  Primes found: " + multiCount);
        System.out.printf("  Time: %.3f ms\n\n", elapsedMulti / 1_000_000.0);

        double speedup = (double) elapsedSingle / elapsedMulti;
        System.out.printf("Speedup: %.2fx\n", speedup);
    }
}