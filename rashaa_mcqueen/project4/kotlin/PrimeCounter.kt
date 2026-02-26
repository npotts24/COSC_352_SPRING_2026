import java.io.File
import java.util.concurrent.Executors

fun main(args: Array<String>) {

    if (args.isEmpty()) {
        println("Usage: kotlin PrimeCounter.kt <file_path>")
        return
    }

    val numbers = readFile(args[0])

    println("File: ${args[0]} (${numbers.size} numbers)\n")

    val startSingle = System.nanoTime()
    val singleCount = numbers.count { isPrime(it) }
    val singleTime = (System.nanoTime() - startSingle) / 1_000_000.0

    println("[Single-Threaded]")
    println("  Primes found: $singleCount")
    println("  Time: %.2f ms\n".format(singleTime))

    val threads = Runtime.getRuntime().availableProcessors()
    val executor = Executors.newFixedThreadPool(threads)

    val startMulti = System.nanoTime()

    val chunkSize = numbers.size / threads
    val futures = (0 until threads).map { i ->
        val start = i * chunkSize
        val end = if (i == threads - 1) numbers.size else start + chunkSize

        executor.submit<Long> {
            numbers.subList(start, end).count { isPrime(it) }.toLong()
        }
    }

    val multiCount = futures.sumOf { it.get() }
    val multiTime = (System.nanoTime() - startMulti) / 1_000_000.0

    executor.shutdown()

    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: $multiCount")
    println("  Time: %.2f ms\n".format(multiTime))

    println("Speedup: %.2fx".format(singleTime / multiTime))
}

fun readFile(path: String): List<Long> =
    File(path).readLines()
        .mapNotNull { it.trim().toLongOrNull() }

fun isPrime(n: Long): Boolean {
    if (n <= 1) return false
    if (n <= 3) return true
    if (n % 2 == 0L || n % 3 == 0L) return false

    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2) == 0L)
            return false
        i += 6
    }
    return true
}