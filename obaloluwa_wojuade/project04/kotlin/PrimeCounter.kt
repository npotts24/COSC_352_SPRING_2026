import java.io.File
import java.text.NumberFormat
import java.util.Locale
import java.util.concurrent.Callable
import java.util.concurrent.Executors

object PrimeCounter {

    private fun isPrime(n: Long): Boolean {
        if (n <= 1) return false
        if (n <= 3) return true
        if (n % 2L == 0L || n % 3L == 0L) return false

        var i = 5L
        while (i * i <= n) {
            if (n % i == 0L || n % (i + 2L) == 0L) return false
            i += 6L
        }
        return true
    }

    private fun readNumbers(path: String): List<Long> {
        val numbers = mutableListOf<Long>()
        File(path).forEachLine { line ->
            val trimmed = line.trim()
            if (trimmed.isEmpty()) return@forEachLine
            val value = trimmed.toLongOrNull()
            if (value != null) {
                numbers.add(value)
            }
        }
        return numbers
    }

    private fun countPrimesSingle(numbers: List<Long>): Long {
        var count = 0L
        for (value in numbers) {
            if (isPrime(value)) count++
        }
        return count
    }

    private fun countRange(numbers: List<Long>, start: Int, end: Int): Long {
        var count = 0L
        for (i in start until end) {
            if (isPrime(numbers[i])) count++
        }
        return count
    }

    private fun countPrimesMulti(numbers: List<Long>, threadCount: Int): Long {
        if (numbers.isEmpty()) return 0L

        val chunkSize = (numbers.size + threadCount - 1) / threadCount
        val pool = Executors.newFixedThreadPool(threadCount)
        val futures = mutableListOf<java.util.concurrent.Future<Long>>()

        var start = 0
        while (start < numbers.size) {
            val end = minOf(start + chunkSize, numbers.size)
            futures += pool.submit(Callable { countRange(numbers, start, end) })
            start = end
        }

        var total = 0L
        for (future in futures) {
            total += future.get()
        }

        pool.shutdown()
        return total
    }

    @JvmStatic
    fun main(args: Array<String>) {
        if (args.isEmpty()) {
            println("Usage: java -jar PrimeCounter.jar <input-file>")
            return
        }

        val filePath = args[0]
        val numbers = try {
            readNumbers(filePath)
        } catch (_: Exception) {
            println("Could not read file: $filePath")
            println("Usage: java -jar PrimeCounter.jar <input-file>")
            return
        }

        val intFormat = NumberFormat.getIntegerInstance(Locale.US)
        val threads = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)

        println("File: $filePath (${intFormat.format(numbers.size)} numbers)")
        println()

        val singleStart = System.nanoTime()
        val singleCount = countPrimesSingle(numbers)
        val singleNs = System.nanoTime() - singleStart

        val multiStart = System.nanoTime()
        val multiCount = countPrimesMulti(numbers, threads)
        val multiNs = System.nanoTime() - multiStart

        val singleMs = singleNs / 1_000_000.0
        val multiMs = multiNs / 1_000_000.0
        val speedup = if (multiMs > 0) singleMs / multiMs else 0.0

        println("[Single-Threaded]")
        println("  Primes found: ${intFormat.format(singleCount)}")
        println("  Time: ${"%.3f".format(singleMs)} ms")
        println()

        println("[Multi-Threaded] ($threads threads)")
        println("  Primes found: ${intFormat.format(multiCount)}")
        println("  Time: ${"%.3f".format(multiMs)} ms")
        println()

        if (singleCount != multiCount) {
            println("WARNING: prime counts do not match.")
        }
        println("Speedup: ${"%.2f".format(speedup)}x")
    }
}