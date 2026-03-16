import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    public static void main(String[] args) {

        if (args.length == 0) {
            System.out.println("Usage: java PrimeCounter <file_path>");
            return;
        }

        ArrayList<Long> numbers = new ArrayList<>();

        // Read file first (not timed)
        try {
            Scanner file = new Scanner(new File(args[0]));
            while (file.hasNextLine()) {
                String line = file.nextLine().trim();
                if (!line.equals("")) {
                    try {
                        numbers.add(Long.parseLong(line));
                    } catch (Exception e) {
                        // skip bad lines
                    }
                }
            }
            file.close();
        } catch (Exception e) {
            System.out.println("Error reading file.");
            return;
        }

        System.out.println("File: " + args[0] + " (" + numbers.size() + " numbers)\n");

        // ---------------- Single Thread ----------------
        long start1 = System.nanoTime();

        long count1 = 0;
        for (long n : numbers) {
            if (isPrime(n)) {
                count1++;
            }
        }

        long end1 = System.nanoTime();
        double time1 = (end1 - start1) / 1_000_000.0;

        // ---------------- Multi Thread ----------------
        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService pool = Executors.newFixedThreadPool(threads);

        long start2 = System.nanoTime();

        int size = numbers.size();
        int chunk = size / threads;

        ArrayList<Future<Long>> results = new ArrayList<>();

        for (int t = 0; t < threads; t++) {

            int start = t * chunk;
            int end = (t == threads - 1) ? size : start + chunk;

            results.add(pool.submit(() -> {
                long local = 0;
                for (int i = start; i < end; i++) {
                    if (isPrime(numbers.get(i))) {
                        local++;
                    }
                }
                return local;
            }));
        }

        long count2 = 0;
        for (Future<Long> f : results) {
            try {
                count2 += f.get();
            } catch (Exception e) {}
        }

        long end2 = System.nanoTime();
        double time2 = (end2 - start2) / 1_000_000.0;

        pool.shutdown();

        System.out.printf("File: %s (%,d numbers)%n%n", args[0], numbers.size());

        System.out.println("[Single-Threaded]");
        System.out.printf("  Primes found: %,d%n", count1);
        System.out.printf("  Time: %.1f ms%n%n", time1);

        System.out.printf("[Multi-Threaded] (%d threads)%n", threads);
        System.out.printf("  Primes found: %,d%n", count2);
        System.out.printf("  Time: %.1f ms%n%n", time2);

        System.out.printf("Speedup: %.2fx%n", time1 / time2);
    }

    public static boolean isPrime(long n) {

        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
        }

        return true;
    }
}