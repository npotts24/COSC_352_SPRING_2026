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

fun main(args: Array<String>) {

    if (args.isEmpty()) {
        println("Usage: kotlin PrimeCounter.kt <file>")
        return
    }

    val numbers = File(args[0]).readLines()
        .mapNotNull { it.trim().toLongOrNull() }

    println("File: ${args[0]} (${numbers.size} numbers)")

    var primeCount = 0L
    val singleTime = measureNanoTime {
        primeCount = numbers.count { isPrime(it) }.toLong()
    }

    println("\n[Single-Threaded]")
    println("Primes found: $primeCount")
    println("Time: ${singleTime / 1_000_000.0} ms")

    val threads = Runtime.getRuntime().availableProcessors()
    val executor = Executors.newFixedThreadPool(threads)

    var total = 0L
    val multiTime = measureNanoTime {

        val chunkSize = numbers.size / threads
        val futures = (0 until threads).map { i ->
            val start = i * chunkSize
            val end = if (i == threads - 1) numbers.size else start + chunkSize

            executor.submit<Long> {
                var local = 0L
                for (j in start until end)
                    if (isPrime(numbers[j])) local++
                local
            }
        }

        total = futures.sumOf { it.get() }
    }

    executor.shutdown()

    println("\n[Multi-Threaded] ($threads threads)")
    println("Primes found: $total")
    println("Time: ${multiTime / 1_000_000.0} ms")

    println("\nSpeedup: ${(singleTime.toDouble() / multiTime)}x")
}
