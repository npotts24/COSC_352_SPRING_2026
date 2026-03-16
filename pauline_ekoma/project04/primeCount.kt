import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.Future
import kotlin.system.measureNanoTime

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

fun readNumbers(filePath: String): List<Long> =
    File(filePath).readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .mapNotNull { it.toLongOrNull() }

fun singleThreadedCount(numbers: List<Long>): Long =
    numbers.count { isPrime(it) }.toLong()

fun multiThreadedCount(numbers: List<Long>): Pair<Long, Int> {
    val threadCount = Runtime.getRuntime().availableProcessors()
    val pool = Executors.newFixedThreadPool(threadCount)

    val chunkSize = (numbers.size + threadCount - 1) / threadCount
    val futures: List<Future<Long>> = numbers
        .chunked(chunkSize)
        .map { chunk -> pool.submit<Long> { chunk.count { isPrime(it) }.toLong() } }

    val total = futures.sumOf { it.get() }
    pool.shutdown()
    return total to threadCount
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin PrimeCounter <file>")
        System.exit(1)
    }

    val filePath = args[0]
    val numbers = try {
        readNumbers(filePath)
    } catch (e: Exception) {
        System.err.println("Error reading file: ${e.message}")
        System.exit(1)
        return
    }

    println("File: $filePath (${"%,d".format(numbers.size)} numbers)\n")

    var singleCount = 0L
    val singleNs = measureNanoTime { singleCount = singleThreadedCount(numbers) }
    val singleMs = singleNs / 1_000_000.0

    println("[Single-Threaded]")
    println("  Primes found: ${"${"%,d".format(singleCount)}"}")
    println("  Time: ${"%.2f".format(singleMs)} ms\n")

    var multiCount = 0L
    var threadCount = 0
    val multiNs = measureNanoTime {
        val result = multiThreadedCount(numbers)
        multiCount = result.first
        threadCount = result.second
    }
    val multiMs = multiNs / 1_000_000.0

    println("[Multi-Threaded] ($threadCount threads)")
    println("  Primes found: ${"${"%,d".format(multiCount)}"}")
    println("  Time: ${"%.2f".format(multiMs)} ms\n")

    if (singleCount != multiCount) {
        System.err.println("WARNING: Prime counts differ between approaches!")
    }

    val speedup = singleMs / multiMs
    println("Speedup: ${"%.2f".format(speedup)}x")
}