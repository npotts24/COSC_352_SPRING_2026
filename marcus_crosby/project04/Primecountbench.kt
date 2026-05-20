import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.util.concurrent.Callable
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        println("Usage: kotlin Primecountbench.kt <input-file> [thread-count]")
        return
    }

    val inputPath = Path.of(args[0])
    val threadCount = if (args.size >= 2) parseThreadCount(args[1]) else Runtime.getRuntime().availableProcessors()

    try {
        val numbers = readNumbers(inputPath)
        if (numbers.isEmpty()) {
            println("No numbers found in file: $inputPath")
            return
        }

        val singleStart = System.nanoTime()
        val singlePrimeCount = countPrimeSingleThread(numbers)
        val singleElapsedNanos = System.nanoTime() - singleStart

        val multiStart = System.nanoTime()
        val multiPrimeCount = countPrimeMultiThread(numbers, threadCount)
        val multiElapsedNanos = System.nanoTime() - multiStart

        println("Input file: $inputPath")
        println("Total numbers parsed: ${numbers.size}")
        println()
        println("Single-thread:")
        println("  Prime count: $singlePrimeCount")
        println("  Elapsed time: %.3f ms".format(nanosToMillis(singleElapsedNanos)))
        println()
        println("Multi-thread ($threadCount threads):")
        println("  Prime count: $multiPrimeCount")
        println("  Elapsed time: %.3f ms".format(nanosToMillis(multiElapsedNanos)))

        if (singlePrimeCount != multiPrimeCount) {
            println()
            println("Warning: counts do not match between modes.")
        }
    } catch (e: IOException) {
        System.err.println("Failed to read file: ${e.message}")
    } catch (e: InterruptedException) {
        Thread.currentThread().interrupt()
        System.err.println("Execution interrupted.")
    } catch (e: ExecutionException) {
        System.err.println("Worker task failed: ${e.cause}")
    }
}

private fun parseThreadCount(text: String): Int =
    text.toIntOrNull()?.coerceAtLeast(1) ?: Runtime.getRuntime().availableProcessors()

private fun readNumbers(inputPath: Path): List<Long> {
    val content = Files.readString(inputPath)
    val tokens = content.split(Regex("[^0-9-]+"))
    val numbers = mutableListOf<Long>()

    for (token in tokens) {
        if (token.isBlank() || token == "-") {
            continue
        }
        token.toLongOrNull()?.let { numbers.add(it) }
    }

    return numbers
}

private fun countPrimeSingleThread(numbers: List<Long>): Long {
    var count = 0L
    for (n in numbers) {
        if (isPrime(n)) {
            count++
        }
    }
    return count
}

private fun countPrimeMultiThread(numbers: List<Long>, threadCount: Int): Long {
    val size = numbers.size
    val workers = minOf(threadCount, size)
    val chunkSize = (size + workers - 1) / workers
    val executor = Executors.newFixedThreadPool(workers)

    try {
        val futures = mutableListOf<java.util.concurrent.Future<Long>>()

        var i = 0
        while (i < size) {
            val from = i
            val to = minOf(i + chunkSize, size)
            val task = Callable<Long> {
                var localCount = 0L
                for (j in from until to) {
                    if (isPrime(numbers[j])) {
                        localCount++
                    }
                }
                localCount
            }
            futures.add(executor.submit(task))
            i += chunkSize
        }

        var total = 0L
        for (future in futures) {
            total += future.get()
        }
        return total
    } finally {
        executor.shutdown()
    }
}

private fun isPrime(n: Long): Boolean {
    if (n < 2) return false
    if (n == 2L || n == 3L) return true
    if (n % 2L == 0L || n % 3L == 0L) return false

    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2L) == 0L) {
            return false
        }
        i += 6L
    }

    return true
}

private fun nanosToMillis(nanos: Long): Double = nanos / 1_000_000.0
