import java.io.File
import kotlin.math.sqrt
import kotlin.concurrent.thread
import java.text.NumberFormat

object PrimeCounter {
    /**
     * Efficient primality check using trial division.
     * After checking 2 and 3, only tests divisors of the form 6k±1 up to sqrt(n).
     */
    fun isPrime(n: Long): Boolean {
        if (n < 2) return false
        if (n == 2L) return true
        if (n % 2 == 0L) return false
        if (n == 3L) return true
        if (n % 3 == 0L) return false

        val sqrtN = sqrt(n.toDouble()).toLong()
        var i = 5L
        while (i <= sqrtN) {
            if (n % i == 0L || n % (i + 2) == 0L) {
                return false
            }
            i += 6
        }
        return true
    }

    /**
     * Single-threaded approach: sequentially check all numbers for primality.
     */
    fun singleThreadedCount(numbers: List<Long>): Long {
        var count = 0L
        for (num in numbers) {
            if (isPrime(num)) {
                count++
            }
        }
        return count
    }

    /**
     * Multi-threaded approach: distribute work across multiple threads.
     */
    fun multiThreadedCount(numbers: List<Long>, numThreads: Int): Long {
        val chunkSize = (numbers.size + numThreads - 1) / numThreads
        val results = IntArray(numThreads)
        val threads = mutableListOf<Thread>()

        for (i in 0 until numThreads) {
            val start = i * chunkSize
            val end = minOf(start + chunkSize, numbers.size)

            if (start >= numbers.size) break

            val thread = thread {
                var count = 0L
                for (j in start until end) {
                    if (isPrime(numbers[j])) {
                        count++
                    }
                }
                results[i] = count.toInt()
            }
            threads.add(thread)
        }

        // Wait for all threads to complete
        for (thread in threads) {
            thread.join()
        }

        return results.asSequence().take(threads.size).sumOf { it.toLong() }
    }

    /**
     * Read integers from file, one per line. Skip invalid or blank lines.
     */
    fun readNumbers(filePath: String): List<Long> {
        val numbers = mutableListOf<Long>()
        try {
            File(filePath).useLines { lines ->
                for (line in lines) {
                    val trimmed = line.trim()
                    if (trimmed.isEmpty()) continue

                    try {
                        numbers.add(trimmed.toLong())
                    } catch (e: NumberFormatException) {
                        // Skip invalid lines
                    }
                }
            }
        } catch (e: Exception) {
            System.err.println("Error reading file: ${e.message}")
            System.exit(1)
        }
        return numbers
    }

    /**
     * Format large numbers with thousand separators.
     */
    fun formatNumber(num: Long): String {
        return NumberFormat.getInstance().also { it.isGroupingUsed = true }.format(num)
    }

    @JvmStatic
    fun main(args: Array<String>) {
        if (args.isEmpty()) {
            System.err.println("Usage: kotlin PrimeCounter <file_path>")
            System.exit(1)
            return
        }

        val filePath = args[0]
        val numbers = readNumbers(filePath)

        if (numbers.isEmpty()) {
            System.err.println("No valid numbers found in file.")
            System.exit(1)
            return
        }

        val file = File(filePath)
        val fileSize = file.length()
        println("File: ${file.name} (${formatNumber(numbers.size.toLong())} numbers, ${formatNumber(fileSize)} bytes)\n")

        val numThreads = Runtime.getRuntime().availableProcessors()

        // Single-threaded approach
        var startTime = System.nanoTime()
        val primeCountSingle = singleThreadedCount(numbers)
        val elapsedNanoSingle = System.nanoTime() - startTime
        val elapsedMsSingle = elapsedNanoSingle / 1_000_000.0

        println("[Single-Threaded]")
        println("  Primes found: ${formatNumber(primeCountSingle)}")
        println(String.format("  Time: %.1f ms\n", elapsedMsSingle))

        // Multi-threaded approach
        startTime = System.nanoTime()
        val primeCountMulti = multiThreadedCount(numbers, numThreads)
        val elapsedNanoMulti = System.nanoTime() - startTime
        val elapsedMsMulti = elapsedNanoMulti / 1_000_000.0

        println("[Multi-Threaded] ($numThreads threads)")
        println("  Primes found: ${formatNumber(primeCountMulti)}")
        println(String.format("  Time: %.1f ms\n", elapsedMsMulti))

        // Calculate and display speedup
        val speedup = elapsedMsSingle / elapsedMsMulti
        println(String.format("Speedup: %.2f x", speedup))

        // Verify both approaches found the same count
        if (primeCountSingle != primeCountMulti) {
            System.err.println("Error: Single-threaded ($primeCountSingle) and multi-threaded ($primeCountMulti) counts differ!")
            System.exit(1)
        }
    }
}
