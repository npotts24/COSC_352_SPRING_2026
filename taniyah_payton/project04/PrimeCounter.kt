import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.Future
import kotlin.system.measureNanoTime

/**
 * Efficient primality check using trial division.
 * After checking 2 and 3, only tests factors of the form 6k±1 up to sqrt(n).
 */
fun isPrime(n: Long): Boolean {
    if (n < 2L) return false
    if (n == 2L || n == 3L) return true
    if (n % 2L == 0L || n % 3L == 0L) return false
    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2L) == 0L) return false
        i += 6L
    }
    return true
}

/**
 * Read all valid integers from the file, skipping blank or invalid lines.
 */
fun readNumbers(filePath: String): List<Long> {
    val file = File(filePath)
    if (!file.exists() || !file.canRead()) {
        error("Cannot read file: $filePath")
    }
    return file.bufferedReader()
        .lineSequence()
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .mapNotNull { it.toLongOrNull() }
        .toList()
}

/**
 * Single-threaded: iterate through all numbers sequentially.
 */
fun countPrimesSingleThreaded(numbers: List<Long>): Long =
    numbers.count { isPrime(it) }.toLong()

/**
 * Multi-threaded: split the list into chunks and process concurrently
 * using a fixed thread pool sized to the number of available CPU cores.
 * Uses Kotlin's idiomatic ExecutorService + Future pattern from stdlib.
 */
fun countPrimesMultiThreaded(numbers: List<Long>, threadCount: Int): Long {
    val executor = Executors.newFixedThreadPool(threadCount)
    val chunkSize = (numbers.size + threadCount - 1) / threadCount

    val futures: List<Future<Long>> = numbers
        .chunked(chunkSize)
        .map { chunk ->
            executor.submit<Long> { chunk.count { isPrime(it) }.toLong() }
        }

    val total = futures.sumOf { it.get() }
    executor.shutdown()
    return total
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin PrimeCounterKt <file_path>")
        System.exit(1)
    }

    val filePath = args[0]
    val numbers: List<Long> = try {
        readNumbers(filePath)
    } catch (e: Exception) {
        System.err.println("Error reading file: ${e.message}")
        System.exit(1)
        return
    }

    val threadCount = Runtime.getRuntime().availableProcessors()

    println("File: $filePath (${"%,d".format(numbers.size)} numbers)")
    println()

    // Single-threaded
    var stCount = 0L
    val stNanos = measureNanoTime { stCount = countPrimesSingleThreaded(numbers) }

    println("[Single-Threaded]")
    println("  Primes found: ${"${"%,d".format(stCount)}"}")
    println("  Time: ${"%.1f".format(stNanos / 1_000_000.0)} ms")
    println()

    // Multi-threaded
    var mtCount = 0L
    val mtNanos = measureNanoTime { mtCount = countPrimesMultiThreaded(numbers, threadCount) }

    println("[Multi-Threaded] ($threadCount threads)")
    println("  Primes found: ${"${"%,d".format(mtCount)}"}")
    println("  Time: ${"%.1f".format(mtNanos / 1_000_000.0)} ms")
    println()

    val speedup = stNanos.toDouble() / mtNanos.toDouble()
    println("Speedup: ${"%.2f".format(speedup)}x")
}
