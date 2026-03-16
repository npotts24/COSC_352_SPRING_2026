import java.io.BufferedReader;
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

    private static class InputData {
        List<Long> numbers = new ArrayList<>();
        int invalidLines = 0;
    }

    private static boolean isPrime(long n) {
        if (n <= 1) {
            return false;
        }
        if (n <= 3) {
            return true;
        }
        if (n % 2 == 0 || n % 3 == 0) {
            return false;
        }

        long i = 5;
        while (i * i <= n) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
            i += 6;
        }
        return true;
    }

    private static InputData readNumbers(Path filePath) throws IOException {
        InputData inputData = new InputData();

        try (BufferedReader reader = Files.newBufferedReader(filePath)) {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.isEmpty()) {
                    continue;
                }

                try {
                    inputData.numbers.add(Long.parseLong(trimmed));
                } catch (NumberFormatException ignored) {
                    inputData.invalidLines++;
                }
            }
        }

        return inputData;
    }

    private static long countPrimesSingleThreaded(List<Long> numbers) {
        long count = 0;
        for (long number : numbers) {
            if (isPrime(number)) {
                count++;
            }
        }
        return count;
    }

    private static int determineWorkerCount(int totalNumbers, int availableCores) {
        int safeCores = Math.max(1, availableCores);
        if (totalNumbers <= 0) {
            return 1;
        }
        return Math.min(totalNumbers, safeCores);
    }

    private static long countPrimesMultiThreaded(List<Long> numbers, int workers)
        throws InterruptedException, ExecutionException {
        if (numbers.isEmpty()) {
            return 0;
        }

        ExecutorService executor = Executors.newFixedThreadPool(workers);
        List<Future<Long>> futures = new ArrayList<>();

        int total = numbers.size();
        for (int i = 0; i < workers; i++) {
            int start = i * total / workers;
            int end = (i + 1) * total / workers;

            Callable<Long> task = () -> {
                long localCount = 0;
                for (int index = start; index < end; index++) {
                    if (isPrime(numbers.get(index))) {
                        localCount++;
                    }
                }
                return localCount;
            };

            futures.add(executor.submit(task));
        }

        long totalCount = 0;
        for (Future<Long> future : futures) {
            totalCount += future.get();
        }

        executor.shutdown();
        return totalCount;
    }

    private static String formatNumber(long value) {
        return String.format("%,d", value);
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: java PrimeCounter <input_file>");
            return;
        }

        Path filePath = Paths.get(args[0]);
        if (!Files.exists(filePath)) {
            System.err.println("Error: File not found -> " + filePath);
            return;
        }

        InputData inputData;
        try {
            inputData = readNumbers(filePath);
        } catch (IOException e) {
            System.err.println("Error: Unable to read file -> " + e.getMessage());
            return;
        }

        List<Long> numbers = inputData.numbers;
        int workers = determineWorkerCount(numbers.size(), Runtime.getRuntime().availableProcessors());

        long singleStart = System.nanoTime();
        long singleCount = countPrimesSingleThreaded(numbers);
        long singleElapsedNs = System.nanoTime() - singleStart;

        long multiCount;
        long multiStart = System.nanoTime();
        try {
            multiCount = countPrimesMultiThreaded(numbers, workers);
        } catch (InterruptedException | ExecutionException e) {
            System.err.println("Error: Multi-threaded execution failed -> " + e.getMessage());
            return;
        }
        long multiElapsedNs = System.nanoTime() - multiStart;

        double singleMs = singleElapsedNs / 1_000_000.0;
        double multiMs = multiElapsedNs / 1_000_000.0;
        double speedup = multiMs > 0.0 ? singleMs / multiMs : 0.0;

        System.out.printf("File: %s (%s numbers)%n", filePath.getFileName(), formatNumber(numbers.size()));
        System.out.printf("Skipped invalid lines: %s%n%n", formatNumber(inputData.invalidLines));

        System.out.println("[Single-Threaded]");
        System.out.printf("  Primes found: %s%n", formatNumber(singleCount));
        System.out.printf("  Time: %.3f ms%n%n", singleMs);

        System.out.printf("[Multi-Threaded] (%d threads)%n", workers);
        System.out.printf("  Primes found: %s%n", formatNumber(multiCount));
        System.out.printf("  Time: %.3f ms%n%n", multiMs);

        System.out.printf("Speedup: %.2fx%n", speedup);

        if (singleCount != multiCount) {
            System.out.println("WARNING: Single-threaded and multi-threaded counts do not match.");
        }
    }
}
