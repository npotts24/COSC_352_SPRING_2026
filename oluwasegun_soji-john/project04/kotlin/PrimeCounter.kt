import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import kotlin.system.measureNanoTime

data class InputData(val numbers: List<Long>, val invalidLines: Int)

fun isPrime(n: Long): Boolean {
    if (n <= 1L) return false
    if (n <= 3L) return true
    if (n % 2L == 0L || n % 3L == 0L) return false

    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2L) == 0L) return false
        i += 6L
    }
    return true
}

fun readNumbers(filePath: Path): InputData {
    val numbers = mutableListOf<Long>()
    var invalid = 0

    Files.newBufferedReader(filePath).use { reader ->
        while (true) {
            val line = reader.readLine() ?: break
            val trimmed = line.trim()
            if (trimmed.isEmpty()) continue

            val value = trimmed.toLongOrNull()
            if (value == null) {
                invalid++
            } else {
                numbers.add(value)
            }
        }
    }

    return InputData(numbers, invalid)
}

fun countPrimesSingleThreaded(numbers: List<Long>): Long {
    var count = 0L
    for (n in numbers) {
        if (isPrime(n)) count++
    }
    return count
}

fun determineWorkerCount(totalNumbers: Int, availableCores: Int): Int {
    val safeCores = if (availableCores > 0) availableCores else 1
    return if (totalNumbers <= 0) 1 else minOf(totalNumbers, safeCores)
}

fun countPrimesMultiThreaded(numbers: List<Long>, workers: Int): Long {
    if (numbers.isEmpty()) return 0L

    val pool = Executors.newFixedThreadPool(workers)
    try {
        val futures = mutableListOf<java.util.concurrent.Future<Long>>()
        val total = numbers.size

        for (i in 0 until workers) {
            val start = i * total / workers
            val end = (i + 1) * total / workers

            futures += pool.submit(Callable<Long> {
                var local = 0L
                for (index in start until end) {
                    if (isPrime(numbers[index])) local++
                }
                local
            })
        }

        var sum = 0L
        for (future in futures) {
            sum += future.get()
        }
        return sum
    } finally {
        pool.shutdown()
    }
}

fun formatNumber(value: Long): String = String.format("%,d", value)

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: kotlin PrimeCounter.kt <input_file>")
        return
    }

    val filePath = Paths.get(args[0])
    if (!Files.exists(filePath)) {
        System.err.println("Error: File not found -> $filePath")
        return
    }

    val inputData = try {
        readNumbers(filePath)
    } catch (e: IOException) {
        System.err.println("Error: Unable to read file -> ${e.message}")
        return
    }

    val numbers = inputData.numbers
    val workers = determineWorkerCount(numbers.size, Runtime.getRuntime().availableProcessors())

    var singleCount = 0L
    val singleNs = measureNanoTime {
        singleCount = countPrimesSingleThreaded(numbers)
    }

    var multiCount = 0L
    val multiNs = try {
        measureNanoTime {
            multiCount = countPrimesMultiThreaded(numbers, workers)
        }
    } catch (e: Exception) {
        System.err.println("Error: Multi-threaded execution failed -> ${e.message}")
        return
    }

    val singleMs = singleNs / 1_000_000.0
    val multiMs = multiNs / 1_000_000.0
    val speedup = if (multiMs > 0.0) singleMs / multiMs else 0.0

    println("File: ${filePath.fileName} (${formatNumber(numbers.size.toLong())} numbers)")
    println("Skipped invalid lines: ${formatNumber(inputData.invalidLines.toLong())}")
    println()

    println("[Single-Threaded]")
    println("  Primes found: ${formatNumber(singleCount)}")
    println("  Time: %.3f ms".format(singleMs))
    println()

    println("[Multi-Threaded] ($workers threads)")
    println("  Primes found: ${formatNumber(multiCount)}")
    println("  Time: %.3f ms".format(multiMs))
    println()

    println("Speedup: %.2fx".format(speedup))

    if (singleCount != multiCount) {
        println("WARNING: Single-threaded and multi-threaded counts do not match.")
    }
}
