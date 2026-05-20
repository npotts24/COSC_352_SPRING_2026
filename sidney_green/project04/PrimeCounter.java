import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    public static boolean isPrime(int n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (int i = 5; (long)i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    public static List<Integer> readNumbers(String filePath) throws IOException {
        List<Integer> numbers = new ArrayList<>();
        BufferedReader br = new BufferedReader(new FileReader(filePath));
        String line;

        while ((line = br.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) continue;
            try {
                numbers.add(Integer.parseInt(line));
            } catch (NumberFormatException ignored) {}
        }

        br.close();
        return numbers;
    }

    public static void main(String[] args) throws Exception {

        if (args.length < 1) {
            System.out.println("Usage: java PrimeCounter <file>");
            return;
        }

        String filePath = args[0];
        List<Integer> numbers = readNumbers(filePath);

        System.out.println("File: " + filePath + " (" + numbers.size() + " numbers)\n");

        long startSingle = System.nanoTime();

        int singleCount = 0;
        for (int n : numbers) {
            if (isPrime(n)) singleCount++;
        }

        long endSingle = System.nanoTime();
        double singleTime = (endSingle - startSingle) / 1_000_000.0;

        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService executor = Executors.newFixedThreadPool(threads);

        int chunkSize = numbers.size() / threads;
        List<Future<Integer>> futures = new ArrayList<>();

        long startMulti = System.nanoTime();

        for (int i = 0; i < threads; i++) {
            int start = i * chunkSize;
            int end = (i == threads - 1) ? numbers.size() : start + chunkSize;

            futures.add(executor.submit(() -> {
                int count = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) count++;
                }
                return count;
            }));
        }

        int multiCount = 0;
        for (Future<Integer> f : futures) {
            multiCount += f.get();
        }

        long endMulti = System.nanoTime();
        double multiTime = (endMulti - startMulti) / 1_000_000.0;

        executor.shutdown();

        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + singleCount);
        System.out.printf("  Time: %.2f ms\n\n", singleTime);

        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.println("  Primes found: " + multiCount);
        System.out.printf("  Time: %.2f ms\n\n", multiTime);

        System.out.printf("Speedup: %.2fx\n", singleTime / multiTime);
    }
}
