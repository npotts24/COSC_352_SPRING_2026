import java.io.File
import java.util.concurrent.Executors
import kotlin.system.measureNanoTime

fun isPrime(n: Int): Boolean {
    if (n < 2) return false
    if (n == 2) return true
    if (n % 2 == 0) return false

    var i = 3
    while (i * i <= n) {
        if (n % i == 0) return false
        i += 2
    }
    return true
}

fun main() {
    val filename = "testdata/numbers.txt"
    val numbers = File(filename).readLines().map { it.toInt() }
    val threads = Runtime.getRuntime().availableProcessors()

    println("File: $filename (${numbers.size} numbers)")
    println("CPU Cores Available: $threads\n")

    var singleCount = 0
    val singleTime = measureNanoTime {
        for (n in numbers) {
            if (isPrime(n)) singleCount++
        }
    }

    println("[Single-Threaded]")
    println("  Primes found: %,d".format(singleCount))
    println("  Time: %.2f ms\n".format(singleTime / 1_000_000.0))

    val executor = Executors.newFixedThreadPool(threads)
val chunkSize = numbers.size / threads
val futures = mutableListOf<java.util.concurrent.Future<Int>>()

var multiCount = 0
val multiTime = measureNanoTime {

    for (i in 0 until threads) {
        val start = i * chunkSize
        val end = if (i == threads - 1) numbers.size else start + chunkSize

        futures.add(executor.submit<Int> {
            var local = 0
            for (j in start until end) {
                if (isPrime(numbers[j])) local++
            }
            local
        })
    }

    multiCount = futures.sumOf { it.get() }
}

executor.shutdown()


    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: %,d".format(multiCount))
    println("  Time: %.2f ms\n".format(multiTime / 1_000_000.0))

    val speedup = singleTime.toDouble() / multiTime
    println("Speedup: %.2fx".format(speedup))
}
