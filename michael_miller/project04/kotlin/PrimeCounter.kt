import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong
import kotlin.system.measureNanoTime

fun isPrime(n: Long): Boolean {
    if (n < 2L) return false
    if (n == 2L) return true
    if (n % 2L == 0L) return false
    if (n == 3L) return true
    if (n % 3L == 0L) return false
    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2) == 0L) return false
        i += 6
    }
    return true
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: PrimeCounter <file_path>")
        return
    }
    val filePath = args[0]
    val numbers: List<Long> = try {
        File(filePath).readLines()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .mapNotNull { it.toLongOrNull() }
    } catch (e: Exception) {
        System.err.println("Error reading file: ${e.message}")
        return
    }
    println("File: $filePath (${String.format("%,d", numbers.size)} numbers)")

    // Single-threaded
    var singleCount = 0L
    val singleTime = measureNanoTime {
        singleCount = numbers.count { isPrime(it) }.toLong()
    }
    println("[Single-Threaded] Primes found: ${String.format("%,d", singleCount)}  Time: ${"%.1f".format(singleTime / 1e6)} ms")

    // Multi-threaded using thread pool
    val cores = Runtime.getRuntime().availableProcessors()
    val pool = Executors.newFixedThreadPool(cores)
    val chunkSize = (numbers.size + cores - 1) / cores
    val multiCount = AtomicLong(0)
    val multiTime = measureNanoTime {
        val futures = (0 until cores).map { i ->
            val from = i * chunkSize
            val to = minOf(from + chunkSize, numbers.size)
            pool.submit<Unit> {
                var local = 0L
                for (j in from until to) if (isPrime(numbers[j])) local++
                multiCount.addAndGet(local)
            }
        }
        futures.forEach { it.get() }
    }
    pool.shutdown()
    println("[Multi-Threaded] ($cores threads) Primes found: ${String.format("%,d", multiCount.get())}  Time: ${"%.1f".format(multiTime / 1e6)} ms")
    println("Speedup: ${"%.2f".format(singleTime.toDouble() / multiTime)}x")
}
