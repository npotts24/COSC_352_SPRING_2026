import java.io.File
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.Future
import kotlin.system.measureNanoTime

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        println("Usage: kotlin PrimeCounterKt <file_path>")
        return
    }
    val filePath = args[0]
    val numbers = readNumbers(filePath)
    if (numbers.isEmpty()) {
        println("No valid numbers found in file.")
        return
    }

    println("File: $filePath (${numbers.size} numbers)")

    // Single-threaded
    val singleCount: Long
    val singleTime = measureNanoTime {
        singleCount = countPrimesSingle(numbers)
    } / 1_000_000.0

    println("\n[Single-Threaded]")
    println("  Primes found: ${"%,d".format(singleCount)}")
    println("  Time: %.1f ms".format(singleTime))

    // Multi-threaded
    val cores = Runtime.getRuntime().availableProcessors()
    val multiCount: Long
    val multiTime = measureNanoTime {
        multiCount = countPrimesMulti(numbers, cores)
    } / 1_000_000.0

    println("\n[Multi-Threaded] ($cores threads)")
    println("  Primes found: ${"%,d".format(multiCount)}")
    println("  Time: %.1f ms".format(multiTime))

    val speedup = singleTime / multiTime
    println("Speedup: %.2fx".format(speedup))
}

fun readNumbers(filePath: String): List<Long> {
    val numbers = mutableListOf<Long>()
    try {
        File(filePath).readLines().forEach { line ->
            val trimmed = line.trim()
            if (trimmed.isNotEmpty()) {
                try {
                    val num = trimmed.toLong()
                    if (num > 1) {
                        numbers.add(num)
                    }
                } catch (e: NumberFormatException) {
                    // Skip invalid lines
                }
            }
        }
    } catch (e: Exception) {
        println("Error reading file: ${e.message}")
        kotlin.system.exitProcess(1)
    }
    return numbers
}

fun countPrimesSingle(numbers: List<Long>): Long {
    var count = 0L
    for (num in numbers) {
        if (isPrime(num)) {
            count++
        }
    }
    return count
}

fun countPrimesMulti(numbers: List<Long>, numThreads: Int): Long {
    val executor = Executors.newFixedThreadPool(numThreads)
    val futures = mutableListOf<Future<Long>>()
    val chunkSize = numbers.size / numThreads
    val remainder = numbers.size % numThreads

    var start = 0
    for (i in 0 until numThreads) {
        val end = start + chunkSize + if (i < remainder) 1 else 0
        val chunk = numbers.subList(start, end)
        futures.add(executor.submit(PrimeCounterTask(chunk)))
        start = end
    }

    var totalCount = 0L
    try {
        for (future in futures) {
            totalCount += future.get()
        }
    } catch (e: Exception) {
        e.printStackTrace()
    } finally {
        executor.shutdown()
    }
    return totalCount
}

fun isPrime(n: Long): Boolean {
    if (n <= 1) return false
    if (n <= 3) return true
    if (n % 2 == 0L || n % 3 == 0L) return false
    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2) == 0L) return false
        i += 6
    }
    return true
}

class PrimeCounterTask(private val numbers: List<Long>) : Callable<Long> {
    override fun call(): Long {
        var count = 0L
        for (num in numbers) {
            if (isPrime(num)) {
                count++
            }
        }
        return count
    }
}