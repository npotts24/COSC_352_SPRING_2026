import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class Primes {

    public static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        long limit = (long) Math.sqrt((double) n);
        for (long i = 5; i <= limit; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    public static List<Long> readNumbers(String path) throws IOException {
        File f = new File(path);
        BufferedReader br = new BufferedReader(new FileReader(f));
        List<Long> nums = new ArrayList<>();
        String line;
        while ((line = br.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) continue;
            try {
                long v = Long.parseLong(line);
                nums.add(v);
            } catch (NumberFormatException e) {
                // skip
            }
        }
        br.close();
        return nums;
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java Primes <file>");
            System.exit(1);
        }
        String path = args[0];
        List<Long> nums;
        try {
            nums = readNumbers(path);
        } catch (IOException e) {
            System.out.println("Failed to read file: " + e.getMessage());
            return;
        }

        System.out.printf("File: %s (%d numbers)\n\n", path, nums.size());

        long t1 = System.nanoTime();
        long singleCount = 0;
        for (long v : nums) if (isPrime(v)) singleCount++;
        long t1e = System.nanoTime() - t1;

        System.out.println("[Single-Threaded]");
        System.out.printf("  Primes found: %d\n", singleCount);
        System.out.printf("  Time: %.3f ms\n\n", t1e / 1e6);

        int threads = Runtime.getRuntime().availableProcessors();
        int chunk = (nums.size() + threads - 1) / threads;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        List<Callable<Long>> tasks = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            final int lo = i * chunk;
            int hi = Math.min(lo + chunk, nums.size());
            if (lo >= nums.size()) break;
            final List<Long> slice = nums.subList(lo, hi);
            tasks.add(() -> {
                long local = 0;
                for (long v : slice) if (isPrime(v)) local++;
                return local;
            });
        }

        long t2 = System.nanoTime();
        long total = 0;
        try {
            List<Future<Long>> futures = pool.invokeAll(tasks);
            for (Future<Long> f : futures) total += f.get();
        } catch (InterruptedException | ExecutionException e) {
            System.out.println("Execution error: " + e.getMessage());
            pool.shutdownNow();
            return;
        }
        long t2e = System.nanoTime() - t2;
        pool.shutdown();

        System.out.printf("[Multi-Threaded] (%d threads)\n", threads);
        System.out.printf("  Primes found: %d\n", total);
        System.out.printf("  Time: %.3f ms\n\n", t2e / 1e6);

        double speedup = (double) t1e / (double) t2e;
        System.out.printf("Speedup: %.2fx\n", speedup);
    }
}
