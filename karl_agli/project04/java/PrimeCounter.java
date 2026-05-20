import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

public class PrimeCounter {

    // Check if a number is prime using trial division
    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n == 2 || n == 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        
        // Check factors of form 6k±1 up to sqrt(n)
        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
        }
        return true;
    }

    // Count primes in a list sequentially
    private static int countPrimesSingleThreaded(List<Long> numbers) {
        int count = 0;
        for (long num : numbers) {
            if (isPrime(num)) {
                count++;
            }
        }
        return count;
    }

    // Count primes using multiple threads
    private static int countPrimesMultiThreaded(List<Long> numbers, int threadCount) throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        List<Future<Integer>> futures = new ArrayList<>();
        
        int chunkSize = (int) Math.ceil((double) numbers.size() / threadCount);
        
        for (int i = 0; i < threadCount; i++) {
            final int start = i * chunkSize;
            final int end = Math.min(start + chunkSize, numbers.size());
            
            if (start >= numbers.size()) break;
            
            Callable<Integer> task = () -> {
                int localCount = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) {
                        localCount++;
                    }
                }
                return localCount;
            };
            
            futures.add(executor.submit(task));
        }
        
        int totalCount = 0;
        for (Future<Integer> future : futures) {
            totalCount += future.get();
        }
        
        executor.shutdown();
        return totalCount;
    }

    // Read numbers from file
    private static List<Long> readNumbersFromFile(String filePath) throws IOException {
        List<Long> numbers = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(new FileReader(filePath))) {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;
                try {
                    numbers.add(Long.parseLong(line));
                } catch (NumberFormatException e) {
                    // Skip invalid lines
                }
            }
        }
        return numbers;
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java PrimeCounter <input_file>");
            System.exit(1);
        }

        String filePath = args[0];
        
        try {
            // Read all numbers first
            List<Long> numbers = readNumbersFromFile(filePath);
            
            if (numbers.isEmpty()) {
                System.out.println("No valid numbers found in file");
                System.exit(1);
            }
            
            System.out.println("File: " + filePath + " (" + String.format("%,d", numbers.size()) + " numbers)");
            
            // Single-threaded approach
            long startTime = System.nanoTime();
            int singleThreadedCount = countPrimesSingleThreaded(numbers);
            long endTime = System.nanoTime();
            double singleThreadedTime = (endTime - startTime) / 1_000_000.0;
            
            System.out.println("\n[Single-Threaded]");
            System.out.println("Primes found: " + String.format("%,d", singleThreadedCount));
            System.out.println("Time: " + String.format("%.1f", singleThreadedTime) + " ms");
            
            // Multi-threaded approach
            int threadCount = Runtime.getRuntime().availableProcessors();
            startTime = System.nanoTime();
            int multiThreadedCount = countPrimesMultiThreaded(numbers, threadCount);
            endTime = System.nanoTime();
            double multiThreadedTime = (endTime - startTime) / 1_000_000.0;
            
            System.out.println("\n[Multi-Threaded] (" + threadCount + " threads)");
            System.out.println("Primes found: " + String.format("%,d", multiThreadedCount));
            System.out.println("Time: " + String.format("%.1f", multiThreadedTime) + " ms");
            
            double speedup = singleThreadedTime / multiThreadedTime;
            System.out.println("\nSpeedup: " + String.format("%.2f", speedup) + "x");
            
        } catch (IOException e) {
            System.err.println("Error reading file: " + e.getMessage());
            System.exit(1);
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        }
    }
}
