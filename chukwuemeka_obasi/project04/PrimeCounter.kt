import java.io.File
import java.util.concurrent.Executors
import kotlin.system.measureNanoTime

fun main(args: Array<String>) {

    if (args.isEmpty()) {
        println("Usage: kotlin PrimeCounterKt <file_path>")
        return
    }

    val numbers = ArrayList<Long>()

    try {
        File(args[0]).forEachLine {
            val line = it.trim()
            if (line != "") {
                val num = line.toLongOrNull()
                if (num != null) {
                    numbers.add(num)
                }
            }
        }
    } catch (e: Exception) {
        println("Error reading file.")
        return
    }

    println("File: ${args[0]} (${numbers.size} numbers)\n")

    // Single thread
    var count1 = 0L
    val time1 = measureNanoTime {
        for (n in numbers) {
            if (isPrime(n)) {
                count1++
            }
        }
    } / 1_000_000.0

    // Multi thread
    val threads = Runtime.getRuntime().availableProcessors()
    val pool = Executors.newFixedThreadPool(threads)

    var count2 = 0L
    val time2 = measureNanoTime {

        val size = numbers.size
        val chunk = size / threads
        val futures = ArrayList<java.util.concurrent.Future<Long>>()

        for (t in 0 until threads) {

            val start = t * chunk
            val end = if (t == threads - 1) size else start + chunk

            futures.add(pool.submit<Long> {
                var local = 0L
                for (i in start until end) {
                    if (isPrime(numbers[i])) {
                        local++
                    }
                }
                local
            })
        }

        for (f in futures) {
            count2 += f.get()
        }
    }

    pool.shutdown()

    println("[Single-Threaded]")
    println("  Primes found: $count1")
    println("  Time: $time1 ms\n")

    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: $count2")
    println("  Time: ${time2 / 1_000_000.0} ms\n")

    println("Speedup: ${time1 / (time2 / 1_000_000.0)}x")
}

fun isPrime(n: Long): Boolean {

    if (n <= 1) return false
    if (n <= 3) return true
    if (n % 2 == 0L || n % 3 == 0L) return false

    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2) == 0L) {
            return false
        }
        i += 6
    }

    return true
}