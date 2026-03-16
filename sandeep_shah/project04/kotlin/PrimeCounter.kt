import java.io.File
import java.util.concurrent.Executors
import kotlin.system.measureNanoTime

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

fun readNumbers(filePath: String): List<Long> {
    return File(filePath).readLines()
        .mapNotNull {
            it.trim().toLongOrNull()
        }
}

fun main(args: Array<String>) {

    if (args.size != 1) {
        println("Usage: kotlin PrimeCounter.kt <input_file>")
        return
    }

    val numbers = try {
        readNumbers(args[0])
    } catch (e: Exception) {
        println("Error reading file: ${args[0]}")
        return
    }

    println("File: ${args[0]} (${numbers.size} numbers)")

    var singleCount = 0L
    val singleTime = measureNanoTime {
        for (n in numbers) {
            if (isPrime(n)) singleCount++
        }
    }

    val numThreads = Runtime.getRuntime().availableProcessors()
    val executor = Executors.newFixedThreadPool(numThreads)
    val chunkSize = numbers.size / numThreads

    var multiCount = 0L
    val multiTime = measureNanoTime {

        val futures = (0 until numThreads).map { i ->
            val start = i * chunkSize
            val end = if (i == numThreads - 1) numbers.size else start + chunkSize
            executor.submit<Long> {
                var local = 0L
                for (n in numbers.subList(start, end)) {
                    if (isPrime(n)) local++
                }
                local
            }
        }

        for (f in futures) {
            multiCount += f.get()
        }
    }

    executor.shutdown()

    println("\n[Single-Threaded]")
    println("  Primes found: $singleCount")
    println("  Time: ${singleTime / 1_000_000.0} ms")

    println("\n[Multi-Threaded] ($numThreads threads)")
    println("  Primes found: $multiCount")
    println("  Time: ${multiTime / 1_000_000.0} ms")

    if (multiTime > 0)
        println("\nSpeedup: %.2fx".format(singleTime.toDouble() / multiTime))
}
