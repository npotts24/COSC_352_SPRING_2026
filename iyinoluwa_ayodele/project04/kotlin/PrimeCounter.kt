import java.io.File
import java.util.concurrent.Executors
import kotlin.math.sqrt

/**
 * Efficient primality test using trial division optimized with 6k±1 pattern.
 */
fun isPrime(n: Int): Boolean {
    if (n < 2) return false
    if (n == 2) return true
    if (n == 3) return true
    if (n % 2 == 0) return false
    if (n % 3 == 0) return false
    
    // Check factors of the form 6k±1 up to sqrt(n)
    var i = 5L
    while (i * i <= n) {
        if (n % i == 0 || n % (i + 2) == 0) {
            return false
        }
        i += 6
    }
    return true
}

/**
 * Read integers from file, skipping invalid entries.
 */
fun readNumbers(filePath: String): List<Int> {
    return File(filePath)
        .readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .mapNotNull { line ->
            try {
                line.toInt()
            } catch (e: NumberFormatException) {
                null
            }
        }
}

/**
 * Single-threaded prime counter.
 */
fun countPrimesSingleThreaded(numbers: List<Int>): Long {
    return numbers.count { isPrime(it) }.toLong()
}

/**
 * Multi-threaded prime counter using thread pool.
 */
fun countPrimesMultiThreaded(numbers: List<Int>, threadCount: Int): Long {
    val executor = Executors.newFixedThreadPool(threadCount)
    val chunkSize = maxOf(1, numbers.size / threadCount)
    
    val futures = numbers
        .chunked(chunkSize)
        .map { chunk ->
            executor.submit {
                chunk.count { isPrime(it) }.toLong()
            }
        }
    
    val totalCount = futures.sumOf { it.get() }
    executor.shutdown()
    
    return totalCount
}

/**
 * Format number with thousands separator.
 */
fun formatNumber(num: Long): String = String.format("%,d", num)

/**
 * Format time in milliseconds with one decimal place.
 */
fun formatTime(nanos: Long): String = String.format("%.1f", nanos / 1_000_000.0)

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin PrimeCounterKt <file_path>")
        System.exit(1)
    }
    
    val filePath = args[0]
    
    try {
        // Read file
        val numbers = readNumbers(filePath)
        
        if (numbers.isEmpty()) {
            System.err.println("Error: File contains no valid integers.")
            System.exit(1)
        }
        
        // Get file info
        val file = File(filePath)
        val fileName = file.name
        
        println("File: $fileName (${formatNumber(numbers.size.toLong())} numbers)\n")
        
        // Single-threaded run
        var startTime = System.nanoTime()
        val countSingle = countPrimesSingleThreaded(numbers)
        val durationSingle = System.nanoTime() - startTime
        
        println("[Single-Threaded]")
        println("  Primes found: ${formatNumber(countSingle)}")
        println("  Time: ${formatTime(durationSingle)} ms\n")
        
        // Multi-threaded run
        val threadCount = Runtime.getRuntime().availableProcessors()
        startTime = System.nanoTime()
        val countMulti = countPrimesMultiThreaded(numbers, threadCount)
        val durationMulti = System.nanoTime() - startTime
        
        println("[Multi-Threaded] ($threadCount threads)")
        println("  Primes found: ${formatNumber(countMulti)}")
        println("  Time: ${formatTime(durationMulti)} ms\n")
        
        // Verify correctness
        if (countSingle != countMulti) {
            System.err.println("ERROR: Prime counts differ!")
            System.exit(1)
        }
        
        // Calculate and display speedup
        val speedup = durationSingle.toDouble() / durationMulti
        println("Speedup: ${String.format("%.2f", speedup)}x")
        
    } catch (e: Exception) {
        when (e) {
            is java.io.FileNotFoundException -> System.err.println("Error: File not found: $filePath")
            is java.io.IOException -> System.err.println("Error reading file: ${e.message}")
            is InterruptedException -> System.err.println("Error in multi-threaded execution: ${e.message}")
            else -> System.err.println("Error: ${e.message}")
        }
        System.exit(1)
    }
}