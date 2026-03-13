import java.io.File
import kotlin.system.measureNanoTime
import kotlinx.coroutines.*

// Check if a number is prime using trial division
fun isPrime(n: Long): Boolean {
    if (n <= 1) return false
    if (n == 2L || n == 3L) return true
    if (n % 2 == 0L || n % 3 == 0L) return false
    
    // Check factors of form 6k±1 up to sqrt(n)
    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2) == 0L) {
            return false
        }
        i += 6
    }
    return true
}

// Count primes sequentially
fun countPrimesSingleThreaded(numbers: List<Long>): Int {
    return numbers.count { isPrime(it) }
}

// Count primes using coroutines (Kotlin's approach to concurrency)
suspend fun countPrimesMultiThreaded(numbers: List<Long>, threadCount: Int): Int = coroutineScope {
    val chunkSize = (numbers.size + threadCount - 1) / threadCount
    
    val deferredResults = numbers.chunked(chunkSize).map { chunk ->
        async(Dispatchers.Default) {
            chunk.count { isPrime(it) }
        }
    }
    
    deferredResults.awaitAll().sum()
}

// Read numbers from file
fun readNumbersFromFile(filePath: String): List<Long> {
    val numbers = mutableListOf<Long>()
    File(filePath).useLines { lines ->
        lines.forEach { line ->
            val trimmed = line.trim()
            if (trimmed.isNotEmpty()) {
                try {
                    numbers.add(trimmed.toLong())
                } catch (e: NumberFormatException) {
                    // Skip invalid lines
                }
            }
        }
    }
    return numbers
}

fun main(args: Array<String>) = runBlocking {
    if (args.isEmpty()) {
        println("Usage: kotlin PrimeCounter <input_file>")
        return@runBlocking
    }
    
    val filePath = args[0]
    
    try {
        // Read all numbers first
        val numbers = readNumbersFromFile(filePath)
        
        if (numbers.isEmpty()) {
            println("No valid numbers found in file")
            return@runBlocking
        }
        
        println("File: $filePath (${String.format("%,d", numbers.size)} numbers)")
        
        // Single-threaded approach
        var singleThreadedCount = 0
        val singleThreadedTime = measureNanoTime {
            singleThreadedCount = countPrimesSingleThreaded(numbers)
        } / 1_000_000.0
        
        println("\n[Single-Threaded]")
        println("Primes found: ${String.format("%,d", singleThreadedCount)}")
        println("Time: ${String.format("%.1f", singleThreadedTime)} ms")
        
        // Multi-threaded approach using coroutines
        val threadCount = Runtime.getRuntime().availableProcessors()
        var multiThreadedCount = 0
        val multiThreadedTime = measureNanoTime {
            multiThreadedCount = countPrimesMultiThreaded(numbers, threadCount)
        } / 1_000_000.0
        
        println("\n[Multi-Threaded] ($threadCount threads)")
        println("Primes found: ${String.format("%,d", multiThreadedCount)}")
        println("Time: ${String.format("%.1f", multiThreadedTime)} ms")
        
        val speedup = singleThreadedTime / multiThreadedTime
        println("\nSpeedup: ${String.format("%.2f", speedup)}x")
        
    } catch (e: Exception) {
        System.err.println("Error: ${e.message}")
    }
}
