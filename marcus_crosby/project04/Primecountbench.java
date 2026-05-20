import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public class Primecountbench {

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java Primecountbench <input-file> [thread-count]");
            return;
        }

        Path inputPath = Path.of(args[0]);
        int threadCount = args.length >= 2 ? parseThreadCount(args[1]) : Runtime.getRuntime().availableProcessors();

        try {
            List<Long> numbers = readNumbers(inputPath);
            if (numbers.isEmpty()) {
                System.out.println("No numbers found in file: " + inputPath);
                return;
            }

            long singleStart = System.nanoTime();
            long singlePrimeCount = countPrimeSingleThread(numbers);
            long singleElapsedNanos = System.nanoTime() - singleStart;

            long multiStart = System.nanoTime();
            long multiPrimeCount = countPrimeMultiThread(numbers, threadCount);
            long multiElapsedNanos = System.nanoTime() - multiStart;

            System.out.println("Input file: " + inputPath);
            System.out.println("Total numbers parsed: " + numbers.size());
            System.out.println();
            System.out.println("Single-thread:");
            System.out.println("  Prime count: " + singlePrimeCount);
            System.out.printf("  Elapsed time: %.3f ms%n", nanosToMillis(singleElapsedNanos));
            System.out.println();
            System.out.println("Multi-thread (" + threadCount + " threads):");
            System.out.println("  Prime count: " + multiPrimeCount);
            System.out.printf("  Elapsed time: %.3f ms%n", nanosToMillis(multiElapsedNanos));

            if (singlePrimeCount != multiPrimeCount) {
                System.out.println();
                System.out.println("Warning: counts do not match between modes.");
            }
        } catch (IOException e) {
            System.err.println("Failed to read file: " + e.getMessage());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            System.err.println("Execution interrupted.");
        } catch (ExecutionException e) {
            System.err.println("Worker task failed: " + e.getCause());
        }
    }

    private static int parseThreadCount(String text) {
        try {
            int parsed = Integer.parseInt(text);
            return Math.max(1, parsed);
        } catch (NumberFormatException e) {
            return Runtime.getRuntime().availableProcessors();
        }
    }

    private static List<Long> readNumbers(Path inputPath) throws IOException {
        String content = Files.readString(inputPath);
        String[] tokens = content.split("[^0-9-]+");
        List<Long> numbers = new ArrayList<>();

        for (String token : tokens) {
            if (token.isBlank() || "-".equals(token)) {
                continue;
            }
            try {
                numbers.add(Long.parseLong(token));
            } catch (NumberFormatException ignored) {
                // Skip values outside long range
            }
        }
        return numbers;
    }

    private static long countPrimeSingleThread(List<Long> numbers) {
        long count = 0;
        for (long n : numbers) {
            if (isPrime(n)) {
                count++;
            }
        }
        return count;
    }

    private static long countPrimeMultiThread(List<Long> numbers, int threadCount)
            throws InterruptedException, ExecutionException {
        int size = numbers.size();
        int workers = Math.min(threadCount, size);
        int chunkSize = (size + workers - 1) / workers;
        ExecutorService executor = Executors.newFixedThreadPool(workers);

        try {
            List<Future<Long>> futures = new ArrayList<>();
            for (int i = 0; i < size; i += chunkSize) {
                int from = i;
                int to = Math.min(i + chunkSize, size);
                Callable<Long> task = () -> {
                    long localCount = 0;
                    for (int j = from; j < to; j++) {
                        if (isPrime(numbers.get(j))) {
                            localCount++;
                        }
                    }
                    return localCount;
                };
                futures.add(executor.submit(task));
            }

            long total = 0;
            for (Future<Long> future : futures) {
                total += future.get();
            }
            return total;
        } finally {
            executor.shutdown();
        }
    }

    private static boolean isPrime(long n) {
        if (n < 2) {
            return false;
        }
        if (n == 2 || n == 3) {
            return true;
        }
        if (n % 2 == 0 || n % 3 == 0) {
            return false;
        }

        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
        }
        return true;
    }

    private static double nanosToMillis(long nanos) {
        return nanos / 1_000_000.0;
    }
}
