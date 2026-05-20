import java.io.BufferedReader
import java.io.FileReader
import java.io.IOException
import kotlin.math.min

object PrimeCounter {

    // Efficient trial division: check 2, 3 then 6k±1 up to sqrt(n)
    private fun isPrime(n: Long): Boolean {
        if (n <= 1L) return false
        if (n <= 3L) return true
        if (n % 2L == 0L || n % 3L == 0L) return false

        var i = 5L
        while (i <= n / i) { // avoids overflow vs i*i <= n
            if (n % i == 0L || n % (i + 2L) == 0L) return false
            i += 6L
        }
        return true
    }

    private fun countPrimesSingle(nums: LongArray): Long {
        var count = 0L
        for (x in nums) {
            if (isPrime(x)) count++
        }
        return count
    }

    private fun countPrimesMulti(nums: LongArray, threadsRequested: Int): Long {
        val n = nums.size
        if (n == 0) return 0L

        val threads = maxOf(1, min(threadsRequested, n))
        val chunkSize = (n + threads - 1) / threads

        val results = LongArray(threads) { 0L }
        val workers = ArrayList<Thread>(threads)

        for (t in 0 until threads) {
            val start = t * chunkSize
            val end = min(n, start + chunkSize)
            if (start >= end) break

            val thread = Thread {
                var local = 0L
                for (i in start until end) {
                    if (isPrime(nums[i])) local++
                }
                results[t] = local
            }
            workers.add(thread)
            thread.start()
        }

        for (w in workers) w.join()

        var total = 0L
        for (v in results) total += v
        return total
    }

    private fun readAllNumbers(path: String): LongArray {
        val list = ArrayList<Long>(1024)

        BufferedReader(FileReader(path)).use { br ->
            while (true) {
                val line = br.readLine() ?: break
                val s = line.trim()
                if (s.isEmpty()) continue
                val v = s.toLongOrNull() ?: continue // skip invalid lines
                list.add(v)
            }
        }

        val arr = LongArray(list.size)
        for (i in list.indices) arr[i] = list[i]
        return arr
    }

    private fun usage() {
        println("Usage: kotlin PrimeCounterKt <path-to-numbers.txt>")
        println("  File must contain one integer per line. Invalid/blank lines are skipped.")
    }

    @JvmStatic
    fun main(args: Array<String>) {
        if (args.isEmpty()) {
            usage()
            return
        }

        val path = args[0]
        val nums: LongArray = try {
            readAllNumbers(path)
        } catch (e: IOException) {
            println("Error: Cannot read file: $path")
            println("Details: ${e.message}")
            usage()
            return
        }

        val threads = Runtime.getRuntime().availableProcessors()

        println("Language: Kotlin")
        println("File: $path (${nums.size} numbers)")
        println()

        val t1Start = System.nanoTime()
        val singleCount = countPrimesSingle(nums)
        val t1End = System.nanoTime()
        val singleMs = (t1End - t1Start) / 1_000_000.0

        val t2Start = System.nanoTime()
        val multiCount = countPrimesMulti(nums, threads)
        val t2End = System.nanoTime()
        val multiMs = (t2End - t2Start) / 1_000_000.0

        println("[Single-Threaded]")
        println("  Primes found: ${"%,d".format(singleCount)}")
        println("  Time: ${"%.3f".format(singleMs)} ms")
        println()

        val effectiveThreads = maxOf(1, min(threads, maxOf(nums.size, 1)))
        println("[Multi-Threaded] ($effectiveThreads threads)")
        println("  Primes found: ${"%,d".format(multiCount)}")
        println("  Time: ${"%.3f".format(multiMs)} ms")
        println()

        if (singleCount != multiCount) {
            println("WARNING: counts do not match! (single=$singleCount, multi=$multiCount)")
        }

        val speedup = if (multiMs == 0.0) Double.POSITIVE_INFINITY else singleMs / multiMs
        println("Speedup: ${"%.2f".format(speedup)}x")
    }
}