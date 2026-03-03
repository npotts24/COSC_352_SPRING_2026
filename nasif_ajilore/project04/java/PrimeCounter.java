import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.stream.Collectors;

public class PrimeCounter {
    
    /**
     * Efficient primality test using trial division optimized with 6k±1 pattern.
     * Only checks divisibility by 2 and 3, then factors of the form 6k±1 up to sqrt(n).
     */
    private static boolean isPrime(int n) {
        if (n < 2) return false;
        if (n == 2) return true;
        if (n == 3) return true;
        if (n % 2 == 0) return false;
        if (n % 3 == 0) return false;
        
        // Check factors of the form 6k±1 up to sqrt(n)
        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
        }
        return true;
    }
    
    /**
     * Read integers from file, skipping invalid entries.
     */
    private static List<Integer> readNumbers(String filePath) throws IOException {
        List<Integer> numbers = new ArrayList<>();
        List<String> lines = Files.readAllLines(Paths.get(filePath));
        
        for (String line : lines) {
            line = line.trim();
            if (line.isEmpty()) continue;
            
            try {
                numbers.add(Integer.parseInt(line));
            } catch (NumberFormatException e) {
                // Skip invalid entries silently
            }
        }
        
        return numbers;
    }
    
    /**
     * Single-threaded prime counter.
     */
    private static long countPrimesSingleThreaded(List<Integer> numbers) {
        long count = 0;
        for (int num : numbers) {
            if (isPrime(num)) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * Multi-threaded prime counter using thread pool.
     */
    private static long countPrimesMultiThreaded(List<Integer> numbers, int threadCount) 
            throws InterruptedException, ExecutionException {
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        List<Future<Long>> futures = new ArrayList<>();
        
        // Divide work into chunks
        int chunkSize = Math.max(1, numbers.size() / threadCount);
        
        for (int i = 0; i < numbers.size(); i += chunkSize) {
            int end = Math.min(i + chunkSize, numbers.size());
            List<Integer> chunk = new ArrayList<>(numbers.subList(i, end));
            
            // Submit task to thread pool
            futures.add(executor.submit(() -> {
                long count = 0;
                for (int num : chunk) {
                    if (isPrime(num)) {
                        count++;
                    }
                }
                return count;
            }));
        }
        
        // Collect results from all threads
        long totalCount = 0;
        for (Future<Long> future : futures) {
            totalCount += future.get();
        }
        
        executor.shutdown();
        return totalCount;
    }
    
    /**
     * Format number with thousands separator.
     */
    private static String formatNumber(long num) {
        return String.format("%,d", num);
    }
    
    /**
     * Format time in milliseconds with one decimal place.
     */
    private static String formatTime(long nanos) {
        return String.format("%.1f", nanos / 1_000_000.0);
    }
    
    public static void main(String[] args) {
        if (args.length == 0) {
            System.err.println("Usage: java PrimeCounter <file_path>");
            System.exit(1);
        }
        
        String filePath = args[0];
        
        try {
            // Read file
            List<Integer> numbers = readNumbers(filePath);
            
            if (numbers.isEmpty()) {
                System.err.println("Error: File contains no valid integers.");
                System.exit(1);
            }
            
            // Get file info
            Path path = Paths.get(filePath);
            String fileName = path.getFileName().toString();
            long fileSize = Files.size(path);
            
            System.out.println("File: " + fileName + " (" + formatNumber(numbers.size()) + " numbers)\n");
            
            // Single-threaded run
            long startTime = System.nanoTime();
            long countSingle = countPrimesSingleThreaded(numbers);
            long durationSingle = System.nanoTime() - startTime;
            
            System.out.println("[Single-Threaded]");
            System.out.println("  Primes found: " + formatNumber(countSingle));
            System.out.println("  Time: " + formatTime(durationSingle) + " ms\n");
            
            // Multi-threaded run
            int threadCount = Runtime.getRuntime().availableProcessors();
            startTime = System.nanoTime();
            long countMulti = countPrimesMultiThreaded(numbers, threadCount);
            long durationMulti = System.nanoTime() - startTime;
            
            System.out.println("[Multi-Threaded] (" + threadCount + " threads)");
            System.out.println("  Primes found: " + formatNumber(countMulti));
            System.out.println("  Time: " + formatTime(durationMulti) + " ms\n");
            
            // Verify correctness
            if (countSingle != countMulti) {
                System.err.println("ERROR: Prime counts differ!");
                System.exit(1);
            }
            
            // Calculate and display speedup
            double speedup = (double) durationSingle / durationMulti;
            System.out.println("Speedup: " + String.format("%.2f", speedup) + "x");
            
        } catch (FileNotFoundException e) {
            System.err.println("Error: File not found: " + filePath);
            System.exit(1);
        } catch (IOException e) {
            System.err.println("Error reading file: " + e.getMessage());
            System.exit(1);
        } catch (InterruptedException | ExecutionException e) {
            System.err.println("Error in multi-threaded execution: " + e.getMessage());
            System.exit(1);
        }
    }
}
