import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.stream.*;

public class PrimeCounter {
    
    /**
     * Check if a number is prime using optimized trial division
     * Only checks divisors of the form 6k±1 after 2 and 3
     */
    private static boolean isPrime(long n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        
        // Only check divisors of form 6k ± 1 up to sqrt(n)
        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) {
                return false;
            }
        }
        return true;
    }
    
    /**
     * Count primes using single-threaded approach
     */
    private static long countPrimesSingleThreaded(List<Long> numbers) {
        return numbers.stream()
                .filter(PrimeCounter::isPrime)
                .count();
    }
    
    /**
     * Count primes using multi-threaded approach
     * Divides work among available CPU cores
     */
    private static long countPrimesMultiThreaded(List<Long> numbers, int numThreads) 
            throws InterruptedException, ExecutionException {
        
        ExecutorService executor = Executors.newFixedThreadPool(numThreads);
        
        // Split the list into chunks
        int chunkSize = (numbers.size() + numThreads - 1) / numThreads;
        List<Future<Long>> futures = new ArrayList<>();
        
        for (int i = 0; i < numbers.size(); i += chunkSize) {
            final int start = i;
            final int end = Math.min(i + chunkSize, numbers.size());
            
            Future<Long> future = executor.submit(() -> {
                long count = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) {
                        count++;
                    }
                }
                return count;
            });
            
            futures.add(future);
        }
        
        // Combine results
        long totalPrimes = 0;
        for (Future<Long> future : futures) {
            totalPrimes += future.get();
        }
        
        executor.shutdown();
        return totalPrimes;
    }
    
    /**
     * Read numbers from file
     */
    private static List<Long> readNumbers(String filename) throws IOException {
        List<Long> numbers = new ArrayList<>();
        
        try (BufferedReader reader = Files.newBufferedReader(Paths.get(filename))) {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;
                
                try {
                    numbers.add(Long.parseLong(line));
                } catch (NumberFormatException e) {
                    // Skip invalid lines
                    System.err.println("Skipping invalid line: " + line);
                }
            }
        }
        
        return numbers;
    }
    
    public static void main(String[] args) {
        if (args.length == 0) {
            System.err.println("Usage: java PrimeCounter <input_file>");
            System.exit(1);
        }
        
        String filename = args[0];
        
        try {
            // Read all numbers from file
            List<Long> numbers = readNumbers(filename);
            
            if (numbers.isEmpty()) {
                System.err.println("No valid numbers found in file");
                System.exit(1);
            }
            
            System.out.println("File: " + filename + " (" + String.format("%,d", numbers.size()) + " numbers)");
            System.out.println();
            
            // Single-threaded approach
            System.out.println("[Single-Threaded]");
            long startSingle = System.nanoTime();
            long primesSingle = countPrimesSingleThreaded(numbers);
            long endSingle = System.nanoTime();
            double timeSingle = (endSingle - startSingle) / 1_000_000.0;
            
            System.out.println("  Primes found: " + String.format("%,d", primesSingle));
            System.out.println("  Time: " + String.format("%.1f", timeSingle) + " ms");
            System.out.println();
            
            // Multi-threaded approach
            int numThreads = Runtime.getRuntime().availableProcessors();
            System.out.println("[Multi-Threaded] (" + numThreads + " threads)");
            long startMulti = System.nanoTime();
            long primesMulti = countPrimesMultiThreaded(numbers, numThreads);
            long endMulti = System.nanoTime();
            double timeMulti = (endMulti - startMulti) / 1_000_000.0;
            
            System.out.println("  Primes found: " + String.format("%,d", primesMulti));
            System.out.println("  Time: " + String.format("%.1f", timeMulti) + " ms");
            System.out.println();
            
            // Speedup
            double speedup = timeSingle / timeMulti;
            System.out.println("Speedup: " + String.format("%.2f", speedup) + "x");
            
            // Verify results match
            if (primesSingle != primesMulti) {
                System.err.println("\nWARNING: Results don't match!");
                System.exit(1);
            }
            
        } catch (IOException e) {
            System.err.println("Error reading file: " + e.getMessage());
            System.exit(1);
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}