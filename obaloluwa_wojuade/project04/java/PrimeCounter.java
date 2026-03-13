import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.text.NumberFormat;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class PrimeCounter {

    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        long i = 5;
        while (i * i <= n) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
            i += 6;
        }
        return true;
    }

    private static List<Long> readNumbers(String filePath) throws IOException {
        List<Long> numbers = new ArrayList<>();
        try (BufferedReader reader = Files.newBufferedReader(Path.of(filePath))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.isEmpty()) continue;
                try {
                    numbers.add(Long.parseLong(trimmed));
                } catch (NumberFormatException ignored) {
                    // Skip invalid lines.
                }
            }
        }
        return numbers;
    }

    private static long countPrimesSingle(List<Long> numbers) {
        long count = 0;
        for (long value : numbers) {
            if (isPrime(value)) {
                count++;
            }
        }
        return count;
    }

    private static long countRange(List<Long> numbers, int start, int end) {
        long count = 0;
        for (int i = start; i < end; i++) {
            if (isPrime(numbers.get(i))) {
                count++;
            }
        }
        return count;
    }

    private static long countPrimesMulti(List<Long> numbers, int threadCount)
            throws InterruptedException, ExecutionException {
        int size = numbers.size();
        if (size == 0) return 0;

        int chunkSize = (size + threadCount - 1) / threadCount;
        ExecutorService pool = Executors.newFixedThreadPool(threadCount);
        List<Future<Long>> futures = new ArrayList<>();

        for (int start = 0; start < size; start += chunkSize) {
            int end = Math.min(start + chunkSize, size);
            final int chunkStart = start;
            final int chunkEnd = end;
            Callable<Long> task = () -> countRange(numbers, chunkStart, chunkEnd);
            futures.add(pool.submit(task));
        }

        long total = 0;
        for (Future<Long> future : futures) {
            total += future.get();
        }

        pool.shutdown();
        return total;
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java PrimeCounter <input-file>");
            return;
        }

        String filePath = args[0];
        List<Long> numbers;
        try {
            numbers = readNumbers(filePath);
        } catch (IOException e) {
            System.out.println("Could not read file: " + filePath);
            System.out.println("Usage: java PrimeCounter <input-file>");
            return;
        }

        NumberFormat intFormat = NumberFormat.getIntegerInstance(Locale.US);
        int threads = Math.max(1, Runtime.getRuntime().availableProcessors());

        System.out.println("File: " + filePath + " (" + intFormat.format(numbers.size()) + " numbers)");
        System.out.println();

        long singleStart = System.nanoTime();
        long singleCount = countPrimesSingle(numbers);
        long singleNs = System.nanoTime() - singleStart;

        long multiCount;
        long multiNs;
        try {
            long multiStart = System.nanoTime();
            multiCount = countPrimesMulti(numbers, threads);
            multiNs = System.nanoTime() - multiStart;
        } catch (InterruptedException | ExecutionException e) {
            System.out.println("Parallel execution failed: " + e.getMessage());
            return;
        }

        double singleMs = singleNs / 1_000_000.0;
        double multiMs = multiNs / 1_000_000.0;
        double speedup = multiMs > 0 ? singleMs / multiMs : 0.0;

        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + intFormat.format(singleCount));
        System.out.printf("  Time: %.3f ms%n%n", singleMs);

        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.println("  Primes found: " + intFormat.format(multiCount));
        System.out.printf("  Time: %.3f ms%n%n", multiMs);

        if (singleCount != multiCount) {
            System.out.println("WARNING: prime counts do not match.");
        }
        System.out.printf("Speedup: %.2fx%n", speedup);
    }
}