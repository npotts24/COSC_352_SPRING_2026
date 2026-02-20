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

        // ---------------- Print Results ----------------
        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + count1);
        System.out.println("  Time: " + time1 + " ms\n");

        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.println("  Primes found: " + count2);
        System.out.println("  Time: " + time2 + " ms\n");

        System.out.println("Speedup: " + (time1 / time2) + "x");
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