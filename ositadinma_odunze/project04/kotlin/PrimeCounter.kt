import java.io.File
import kotlin.system.measureTimeMillis

/**
 * Check if a number is prime using optimized trial division
 */
fun isPrime(n: Long): Boolean {
    if (n <= 1) return false
    if (n <= 3) return true
    if (n % 2L == 0L || n % 3L == 0L) return false
    
    // Only check divisors of form 6k ± 1 up to sqrt(n)
    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2) == 0L) {
            return false
        }
        i += 6
    }
    return true
}

/**
 * Count primes using single-threaded approach
 */
fun countPrimesSingleThreaded(numbers: List<Long>): Long {
    return numbers.count { isPrime(it) }.toLong()
}

/**
 * Count primes using multiple threads
 */
fun countPrimesMultiThreaded(numbers: List<Long>, numThreads: Int): Long {
    val chunkSize = (numbers.size + numThreads - 1) / numThreads
    val chunks = numbers.chunked(chunkSize)
    
    val threads = chunks.map { chunk ->
        Thread {
            // Thread will count its chunk
        }
    }
    
    // Use simple thread-based approach
    val results = mutableListOf<Long>()
    val lock = Any()
    
    val threadList = chunks.map { chunk ->
        Thread {
            val count = chunk.count { isPrime(it) }.toLong()
            synchronized(lock) {
                results.add(count)
            }
        }
    }
    
    threadList.forEach { it.start() }
    threadList.forEach { it.join() }
    
    return results.sum()
}

/**
 * Read numbers from file
 */
fun readNumbers(filename: String): List<Long> {
    val numbers = mutableListOf<Long>()
    
    File(filename).useLines { lines ->
        lines.forEach { line ->
            val trimmed = line.trim()
            if (trimmed.isNotEmpty()) {
                try {
                    numbers.add(trimmed.toLong())
                } catch (e: NumberFormatException) {
                    System.err.println("Skipping invalid line: $line")
                }
            }
        }
    }
    
    return numbers
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin PrimeCounter <input_file>")
        kotlin.system.exitProcess(1)
    }
    
    val filename = args[0]
    
    try {
        // Read all numbers from file
        val numbers = readNumbers(filename)
        
        if (numbers.isEmpty()) {
            System.err.println("No valid numbers found in file")
            kotlin.system.exitProcess(1)
        }
        
        println("File: $filename (${"%,d".format(numbers.size)} numbers)")
        println()
        
        // Single-threaded approach
        println("[Single-Threaded]")
        var primesSingle: Long
        val timeSingle = measureTimeMillis {
            primesSingle = countPrimesSingleThreaded(numbers)
        }
        
        println("  Primes found: ${"%,d".format(primesSingle)}")
        println("  Time: ${timeSingle.toDouble()} ms")
        println()
        
        // Multi-threaded approach
        val numThreads = Runtime.getRuntime().availableProcessors()
        println("[Multi-Threaded] ($numThreads threads)")
        var primesMulti: Long
        val timeMulti = measureTimeMillis {
            primesMulti = countPrimesMultiThreaded(numbers, numThreads)
        }
        
        println("  Primes found: ${"%,d".format(primesMulti)}")
        println("  Time: ${timeMulti.toDouble()} ms")
        println()
        
        // Speedup
        val speedup = timeSingle.toDouble() / timeMulti.toDouble()
        println("Speedup: ${"%.2f".format(speedup)}x")
        
        // Verify results match
        if (primesSingle != primesMulti) {
            System.err.println("\nWARNING: Results don't match!")
            kotlin.system.exitProcess(1)
        }
        
    } catch (e: Exception) {
        System.err.println("Error: ${e.message}")
        e.printStackTrace()
        kotlin.system.exitProcess(1)
    }
}