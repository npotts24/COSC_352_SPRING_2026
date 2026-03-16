import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.ceil

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
        println("Usage: kotlin_prime")
        return
    }

    val numbers = mutableListOf<Long>()
    try {
        File(args[0]).forEachLine { line ->
            line.trim().toLongOrNull()?.let { numbers.add(it) }
        }
    } catch (e: Exception) {
        println("Error reading file.")
        return
    }

    // 1. Single-Threaded
    val startS = System.nanoTime()
    var countS = 0L
    for (n in numbers) {
        if (isPrime(n)) countS++
    }
    val timeS = (System.nanoTime() - startS) / 1_000_000.0

    // 2. Multi-Threaded 
    val cores = Runtime.getRuntime().availableProcessors()
    val executor = Executors.newFixedThreadPool(cores)
    val chunkSize = ceil(numbers.size.toDouble() / cores).toInt()
    val futures = mutableListOf<Future<Long>>()

    val startM = System.nanoTime()
    for (i in 0 until cores) {
        val start = i * chunkSize
        val end = minOf(start + chunkSize, numbers.size)
        
        futures.add(executor.submit<Long> {
            var localCount = 0L
            for (j in start until end) {
                if (isPrime(numbers[j])) localCount++
            }
            localCount
        })
    }

    var countM = 0L
    for (f in futures) {
        countM += f.get() 
    }
    executor.shutdown()
    val timeM = (System.nanoTime() - startM) / 1_000_000.0

    // Output
    println("[Single-Threaded]")
    println("Primes found: $countS")
    println("Time: ${"%.1f".format(timeS)} ms")

    println("\n[Multi-Threaded] ($cores threads)")
    println("Primes found: $countM")
    println("Time: ${"%.1f".format(timeM)} ms")
    println("\nSpeedup: ${"%.2f".format(timeS / timeM)}x")
}