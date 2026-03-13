import java.io.File
import java.util.concurrent.Executors
import kotlin.system.exitProcess

fun isPrime(n: Int): Boolean {
    if (n <= 1) return false
    if (n <= 3) return true
    if (n % 2 == 0 || n % 3 == 0) return false

    var i = 5
    while (i * i <= n) {
        if (n % i == 0 || n % (i + 2) == 0) return false
        i += 6
    }
    return true
}

fun readNumbers(filePath: String): List<Int> {
    val numbers = mutableListOf<Int>()
    val file = File(filePath)

    if (!file.exists()) {
        println("Error reading file: $filePath")
        exitProcess(1)
    }

    file.forEachLine { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty()) {
            try {
                numbers.add(trimmed.toInt())
            } catch (e: NumberFormatException) {
                // skip invalid lines
            }
        }
    }
    return numbers
}

fun main(args: Array<String>) {

    if (args.isEmpty()) {
        println("Usage: kotlin PrimeCounter.kt <file>")
        return
    }

    val filePath = args[0]
    val numbers = readNumbers(filePath)

    println("File: $filePath (${numbers.size} numbers)\n")

    // Single-threaded
    val startSingle = System.nanoTime()
    var singleCount = 0
    for (n in numbers) {
        if (isPrime(n)) singleCount++
    }
    val endSingle = System.nanoTime()
    val singleTime = (endSingle - startSingle) / 1_000_000.0

    // Multi-threaded
    val threads = Runtime.getRuntime().availableProcessors()
    val executor = Executors.newFixedThreadPool(threads)
    val chunkSize = numbers.size / threads
    val futures = mutableListOf<java.util.concurrent.Future<Int>>()

    val startMulti = System.nanoTime()

    for (i in 0 until threads) {
        val start = i * chunkSize
        val end = if (i == threads - 1) numbers.size else start + chunkSize

        futures.add(executor.submit<Int> {
            var count = 0
            for (j in start until end) {
                if (isPrime(numbers[j])) count++
            }
            count
        })
    }

    var multiCount = 0
    for (f in futures) {
        multiCount += f.get()
    }

    val endMulti = System.nanoTime()
    val multiTime = (endMulti - startMulti) / 1_000_000.0

    executor.shutdown()

    println("[Single-Threaded]")
    println("  Primes found: $singleCount")
    println("  Time: %.2f ms\n".format(singleTime))

    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: $multiCount")
    println("  Time: %.2f ms\n".format(multiTime))

    println("Speedup: %.2fx".format(singleTime / multiTime))
}
