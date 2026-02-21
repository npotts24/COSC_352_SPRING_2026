import java.nio.file.Files
import java.nio.file.Paths
import java.util.concurrent.Callable
import java.util.concurrent.Executors

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        println("Usage: kotlin PrimeCounterKt <numbers-file>")
        return
    }

    val path = Paths.get(args[0])
    if (!Files.isReadable(path)) {
        println("Cannot read file: $path")
        return
    }

    val numbers = ArrayList<Long>()
    Files.readAllLines(path).forEach { line ->
        val s = line?.trim() ?: return@forEach
        if (s.isEmpty()) return@forEach
        try {
            numbers.add(s.toLong())
        } catch (_: NumberFormatException) {
        }
    }

    println("File: $path (${numbers.size} numbers)\n")

    val singleStart = System.nanoTime()
    var singleCount = 0L
    for (v in numbers) if (isPrime(v)) singleCount++
    val singleMs = (System.nanoTime() - singleStart) / 1_000_000

    println("[Single-Threaded]")
    println("  Primes found: $singleCount")
    println("  Time: ${singleMs} ms\n")

    val threads = Runtime.getRuntime().availableProcessors()
    val ex = Executors.newFixedThreadPool(threads)
    val tasks = ArrayList<Callable<Long>>()

    val n = numbers.size
    val chunk = (n + threads - 1) / threads
    var i = 0
    while (i < n) {
        val lo = i
        val hi = minOf(n, i + chunk)
        tasks.add(Callable {
            var local = 0L
            for (j in lo until hi) if (isPrime(numbers[j])) local++
            local
        })
        i += chunk
    }

    val pStart = System.nanoTime()
    val results = ex.invokeAll(tasks)
    var total = 0L
    results.forEach { total += it.get() }
    val pMs = (System.nanoTime() - pStart) / 1_000_000

    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: $total")
    println("  Time: ${pMs} ms\n")
    val speedup = singleMs.toDouble() / maxOf(1L, pMs).toDouble()
    println(String.format("Speedup: %.2fx", speedup))

    ex.shutdownNow()
}

fun isPrime(n: Long): Boolean {
    if (n <= 1) return false
    if (n <= 3) return true
    if (n % 2L == 0L || n % 3L == 0L) return false
    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2L) == 0L) return false
        i += 6
    }
    return true
}
