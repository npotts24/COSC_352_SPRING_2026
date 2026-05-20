import java.io.File
import kotlin.system.exitProcess
import kotlin.math.sqrt

// Efficient primality test using 6k ± 1 optimization
fun isPrime(n: Long): Boolean {
    if (n <= 1L) return false
    if (n <= 3L) return true
    if (n % 2L == 0L || n % 3L == 0L) return false

    val limit = sqrt(n.toDouble()).toLong()
    var i = 5L
    while (i <= limit) {
        if (n % i == 0L || n % (i + 2L) == 0L) return false
        i += 6L
    }
    return true
}

// Read all numbers before timing
fun readNumbers(path: String): List<Long> {
    val numbers = mutableListOf<Long>()
    File(path).forEachLine { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty()) {
            val value = trimmed.toLongOrNull()
            if (value != null) {
                numbers.add(value)
            }
        }
    }
    return numbers
}

// Single-threaded count
fun countSingle(numbers: List<Long>): Int {
    var count = 0
    for (n in numbers) {
        if (isPrime(n)) count++
    }
    return count
}

// Multi-threaded count
fun countMulti(numbers: List<Long>, threads: Int): Int {
    if (numbers.isEmpty()) return 0

    val chunkSize = numbers.size / threads
    val results = IntArray(threads)
    val threadList = mutableListOf<Thread>()

    for (i in 0 until threads) {
        val start = i * chunkSize
        val end = if (i == threads - 1) numbers.size else start + chunkSize

        val thread = Thread {
            var localCount = 0
            for (index in start until end) {
                if (isPrime(numbers[index])) localCount++
            }
            results[i] = localCount
        }

        threadList.add(thread)
        thread.start()
    }

    for (thread in threadList) {
        thread.join()
    }

    return results.sum()
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        println("Usage: java -jar PrimeCounter.jar <file_path>")
        exitProcess(1)
    }

    val filePath = args[0]

    val numbers = try {
        readNumbers(filePath)
    } catch (e: Exception) {
        println("Error reading file: ${e.message}")
        exitProcess(1)
    }

    println("File: $filePath (${numbers.size} numbers)\n")

    // Single-threaded
    val startSingle = System.nanoTime()
    val singleCount = countSingle(numbers)
    val elapsedSingle = System.nanoTime() - startSingle

    println("[Single-Threaded]")
    println("  Primes found: $singleCount")
    println("  Time: ${elapsedSingle / 1_000_000.0} ms\n")

    // Multi-threaded
    val threads = Runtime.getRuntime().availableProcessors()

    val startMulti = System.nanoTime()
    val multiCount = countMulti(numbers, threads)
    val elapsedMulti = System.nanoTime() - startMulti

    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: $multiCount")
    println("  Time: ${elapsedMulti / 1_000_000.0} ms\n")

    val speedup = elapsedSingle.toDouble() / elapsedMulti.toDouble()
    println("Speedup: %.2fx".format(speedup))
}