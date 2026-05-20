import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class PrimeCounter {
    public static void main(String[] args) throws IOException {
        if (args.length < 1) {
            System.out.println("Usage: java PrimeCounter <numbers-file>");
            return;
        }

        Path path = Paths.get(args[0]);
        if (!Files.isReadable(path)) {
            System.out.println("Cannot read file: " + path);
            return;
        }

        List<Long> numbers = new ArrayList<>();
        for (String line : Files.readAllLines(path)) {
            if (line == null) continue;
            line = line.trim();
            if (line.isEmpty()) continue;
            try {
                long v = Long.parseLong(line);
                numbers.add(v);
            } catch (NumberFormatException ignored) {
            }
        }

        System.out.println("File: " + path + " (" + numbers.size() + " numbers)\n");

        // Single-threaded
        long start = System.nanoTime();
        long singleCount = 0;
        for (long v : numbers) if (isPrime(v)) singleCount++;
        long singleTimeMs = (System.nanoTime() - start) / 1_000_000;

        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + singleCount);
        System.out.println("  Time: " + singleTimeMs + " ms\n");

        // Multi-threaded
        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService ex = Executors.newFixedThreadPool(threads);
        List<Callable<Long>> tasks = new ArrayList<>();

        int n = numbers.size();
        int chunk = (n + threads - 1) / threads;
        for (int i = 0; i < n; i += chunk) {
            int lo = i;
            int hi = Math.min(n, i + chunk);
            tasks.add(() -> {
                long local = 0;
                for (int j = lo; j < hi; j++) {
                    if (isPrime(numbers.get(j))) local++;
                }
                return local;
            });
        }

        long pstart = System.nanoTime();
        try {
            List<Future<Long>> results = ex.invokeAll(tasks);
            long total = 0;
            for (Future<Long> f : results) total += f.get();
            long ptimeMs = (System.nanoTime() - pstart) / 1_000_000;
            System.out.println("[Multi-Threaded] (" + threads + " threads)");
            System.out.println("  Primes found: " + total);
            System.out.println("  Time: " + ptimeMs + " ms\n");
            double speedup = (double) singleTimeMs / Math.max(ptimeMs, 1L);
            System.out.printf("Speedup: %.2fx\n", speedup);
        } catch (InterruptedException | ExecutionException e) {
            System.err.println("Parallel computation failed: " + e.getMessage());
        } finally {
            ex.shutdownNow();
        }
    }

    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        long i = 5;
        while (i * i <= n) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
            i += 6;
        }
        return true;
    }
}
