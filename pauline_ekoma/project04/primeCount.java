import java.util.*;
import java.io.*;

public class primeCount {
    public static boolean isPrime(long k) {
        if (k <= 1) return false;
        if (k <= 3) return true;
        if (k % 2 == 0 || k % 3 == 0) return false;
        
        for (long i = 5; i * i <= k; i += 6) {
            if (k % i == 0 || k % (i+2) == 0) return false;
        }
        return true;
    }
    public static List<Long> readNumbers(String "numbers.txt") throws IOException {
        List<Long> numbers = new ArrayList<>();

        for(String line : Files.readAllLines(Paths.get("numbers.txt"))) {
            line = line.trim();
            if (line.isEmpty()) continue; // skip empty lines

            try {
                numbers.add(Long.parseLong(line));
            } catch (NumberFormatException ignored) {
                // skip invalid lines                
        }
    }
        return numbers;
}
    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.out.println("Usage: java primeCount numbers.txt");
            return;
        }

        List<Long> numbers = readNumbers(args[0]);
        int cores = Runtime.getRuntime().availableProcessors();

        long start = System.nanoTime();
        long singleCount = numbers.stream().filter(primeCount::isPrime).count();
        long singleTime = System.nanoTime() - start;
        System.out.println("[Single-Threaded]");
        System.out.println("    Primes found: " + singleCount);
        System.out.printf("    Time: %.3f ms%n", singleTime / 1_000_000.0);

        start = System.nanoTime();
        long multiTime = System.nanoTime() - start;

        System.out.println("[Multi-Threaded] (" + cores + " threads)");
        System.out.println("    Primes found: " + multiCount);
        System.out.printf("    Time: %.3f ms%n", multiTime / 1_000_000.0);
        System.out.printf("    Speedup: %.2fx%n", (double) singleTime / multiTime);
    }
}