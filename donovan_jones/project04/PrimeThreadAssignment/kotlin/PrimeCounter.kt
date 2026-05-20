import java.io.File
import java.util.concurrent.Executors

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
        println("Usage: java -jar PrimeCounter.jar <file>")
        return
    }

    val numbers = File(args[0]).readLines()
        .mapNotNull { it.toLongOrNull() }

    println("File: ${args[0]} (${numbers.size} numbers)")

    val startSingle = System.nanoTime()
    val singleCount = numbers.count { isPrime(it) }
    val singleTime = System.nanoTime() - startSingle

    println("\n[Single-Threaded]")
    println("Primes found: $singleCount")
    println("Time: ${singleTime / 1_000_000.0} ms")

    val threads = Runtime.getRuntime().availableProcessors()
    val pool = Executors.newFixedThreadPool(threads)
    val chunk = numbers.size / threads

    val startMulti = System.nanoTime()
    val futures = (0 until threads).map { i ->
        val from = i * chunk
        val to = if (i == threads - 1) numbers.size else from + chunk
        pool.submit<Long> {
            var c = 0L
            for (j in from until to)
                if (isPrime(numbers[j])) c++
            c
        }
    }

    val multiCount = futures.sumOf { it.get() }
    pool.shutdown()
    val multiTime = System.nanoTime() - startMulti

    println("\n[Multi-Threaded] ($threads threads)")
    println("Primes found: $multiCount")
    println("Time: ${multiTime / 1_000_000.0} ms")
    println("\nSpeedup: ${singleTime.toDouble() / multiTime}x")
}
