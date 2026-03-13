import java.io.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public class PrimeCounter {

    static boolean isPrime(long n) {
        if (n < 2) return false;
        if (n == 2) return true;
        if (n % 2 == 0) return false;
        if (n == 3) return true;
        if (n % 3 == 0) return false;
        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("Usage: java PrimeCounter <file_path>");
            System.exit(1);
        }
        String filePath = args[0];
        List<Long> numbers = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(new FileReader(filePath))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;
                try { numbers.add(Long.parseLong(line)); } catch (NumberFormatException ignored) {}
            }
        } catch (IOException e) {
            System.err.println("Error reading file: " + e.getMessage());
            System.exit(1);
        }
        int total = numbers.size();
        System.out.printf("File: %s (%,d numbers)%n", filePath, total);

        // Single-threaded
        long st = System.nanoTime();
        long singleCount = 0;
        for (long n : numbers) if (isPrime(n)) singleCount++;
        long singleTime = System.nanoTime() - st;
        System.out.printf("[Single-Threaded] Primes found: %,d  Time: %.1f ms%n", singleCount, singleTime / 1e6);

        // Multi-threaded
        int cores = Runtime.getRuntime().availableProcessors();
        int chunkSize = (total + cores - 1) / cores;
        AtomicLong multiCount = new AtomicLong(0);
        List<Thread> threads = new ArrayList<>();
        long mt = System.nanoTime();
        for (int i = 0; i < cores; i++) {
            final int from = i * chunkSize;
            final int to = Math.min(from + chunkSize, total);
            if (from >= total) break;
            Thread t = new Thread(() -> {
                long local = 0;
                for (int j = from; j < to; j++) if (isPrime(numbers.get(j))) local++;
                multiCount.addAndGet(local);
            });
            threads.add(t);
            t.start();
        }
        for (Thread t : threads) t.join();
        long multiTime = System.nanoTime() - mt;
        System.out.printf("[Multi-Threaded] (%d threads) Primes found: %,d  Time: %.1f ms%n", threads.size(), multiCount.get(), multiTime / 1e6);
        System.out.printf("Speedup: %.2fx%n", (double) singleTime / multiTime);
    }
}
