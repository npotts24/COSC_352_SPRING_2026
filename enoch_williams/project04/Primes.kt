import java.io.File
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import kotlin.math.sqrt

fun isPrime(n: Long): Boolean {
    if (n <= 1L) return false
    if (n <= 3L) return true
    if (n % 2L == 0L || n % 3L == 0L) return false
    val limit = kotlin.math.sqrt(n.toDouble()).toLong()
    var i = 5L
    while (i <= limit) {
        if (n % i == 0L || n % (i + 2) == 0L) return false
        i += 6
    }
    return true
}

fun readNumbers(path: String): List<Long> {
    val file = File(path)
    val list = ArrayList<Long>()
    file.forEachLine { line ->
        val s = line.trim()
        if (s.isEmpty()) return@forEachLine
        val v = s.toLongOrNull()
        if (v != null) list.add(v)
    }
    return list
}

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        println("Usage: kotlin Primes.kt <file>")
        return
    }
    val path = args[0]
    val nums = try {
        readNumbers(path)
    } catch (e: Exception) {
        println("Failed to read file: ${e.message}")
        return
    }

    println("File: $path (${nums.size} numbers)\n")

    val t1 = System.nanoTime()
    var singleCount = 0L
    for (v in nums) if (isPrime(v)) singleCount++
    val t1e = System.nanoTime() - t1

    println("[Single-Threaded]")
    println("  Primes found: $singleCount")
    println("  Time: ${t1e / 1e6} ms\n")

    val threads = Runtime.getRuntime().availableProcessors()
    val chunk = (nums.size + threads - 1) / threads
    val pool = Executors.newFixedThreadPool(threads)
    val tasks = ArrayList<Callable<Long>>()
    var i = 0
    while (i < threads) {
        val lo = i * chunk
        var hi = lo + chunk
        if (lo >= nums.size) break
        if (hi > nums.size) hi = nums.size
        val slice = nums.subList(lo, hi)
        tasks.add(Callable {
            var local = 0L
            for (v in slice) if (isPrime(v)) local++
            local
        })
        i++
    }

    val t2 = System.nanoTime()
    val futures = pool.invokeAll(tasks)
    var total = 0L
    for (f in futures) total += f.get()
    val t2e = System.nanoTime() - t2
    pool.shutdown()

    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: $total")
    println("  Time: ${t2e / 1e6} ms\n")

    val speedup = t1e.toDouble() / t2e.toDouble()
    println("Speedup: ${"%.2f".format(speedup)}x")
}
