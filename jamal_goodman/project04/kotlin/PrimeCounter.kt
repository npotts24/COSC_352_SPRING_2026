import java.nio.file.Files
import java.nio.file.Path
import java.util.Locale
import java.util.concurrent.Callable
import java.util.concurrent.Executors

object PrimeCounter {

    private fun isPrime(n: Long): Boolean {
        if (n <= 1L) return false
        if (n <= 3L) return true
        if (n % 2L == 0L || n % 3L == 0L) return false
        var i = 5L
        while (i <= n / i) {
            if (n % i == 0L || n % (i + 2L) == 0L) return false
            i += 6L
        }
        return true
    }

    private fun readAllNumbers(file: Path): List<Long> {
        val nums = ArrayList<Long>(1024)
        Files.newBufferedReader(file).use { br ->
            while (true) {
                val line = br.readLine() ?: break
                val s = line.trim()
                if (s.isEmpty()) continue
                try {
                    nums.add(s.toLong())
                } catch (_: NumberFormatException) {
                    // skip invalid line gracefully
                }
            }
        }
        return nums
    }

    private fun countSingle(nums: List<Long>): Long {
        var count = 0L
        for (x in nums) if (isPrime(x)) count++
        return count
    }

    private fun countParallel(nums: List<Long>, threads: Int): Long {
        val n = nums.size
        if (n == 0) return 0L

        var t = if (threads < 1) 1 else threads
        if (t > n) t = n

        val pool = Executors.newFixedThreadPool(t)
        try {
            val chunk = (n + t - 1) / t
            val futures = ArrayList<java.util.concurrent.Future<Long>>(t)

            for (i in 0 until t) {
                val start = i * chunk
                val end = minOf(n, start + chunk)
                if (start >= end) break

                futures.add(pool.submit(Callable {
                    var local = 0L
                    for (idx in start until end) {
                        if (isPrime(nums[idx])) local++
                    }
                    local
                }))
            }

            var total = 0L
            for (f in futures) total += f.get()
            return total
        } finally {
            pool.shutdown()
        }
    }

    private fun usage() {
        println("Usage: java -jar kotlin/PrimeCounter.jar <path/to/numbers.txt>")
    }

    @JvmStatic
    fun main(args: Array<String>) {
        Locale.setDefault(Locale.US)

        if (args.isEmpty()) {
            usage()
            return
        }

        val file = Path.of(args[0])
        if (!Files.isReadable(file)) {
            println("Error: cannot read file: $file")
            usage()
            return
        }

        val nums = try {
            readAllNumbers(file) // I/O done BEFORE timing
        } catch (e: Exception) {
            println("Error reading file: ${e.message}")
            return
        }

        val threads = Runtime.getRuntime().availableProcessors()

        println("File: ${file.fileName} (${nums.size} numbers)\n")

        val t1 = System.nanoTime()
        val single = countSingle(nums)
        val t2 = System.nanoTime()
        val singleMs = (t2 - t1) / 1_000_000.0

        println("[Single-Threaded]")
        println("  Primes found: %,d".format(single))
        println("  Time: %.3f ms\n".format(singleMs))

        val t3 = System.nanoTime()
        val multi = try {
            countParallel(nums, threads)
        } catch (e: Exception) {
            println("Error: parallel execution failed: ${e.cause ?: e}")
            return
        }
        val t4 = System.nanoTime()
        val multiMs = (t4 - t3) / 1_000_000.0

        println("[Multi-Threaded] ($threads threads)")
        println("  Primes found: %,d".format(multi))
        println("  Time: %.3f ms\n".format(multiMs))

        if (single != multi) {
            println("WARNING: Counts do not match! single=$single multi=$multi")
        }

        val speedup = if (multiMs > 0) singleMs / multiMs else Double.POSITIVE_INFINITY
        println("Speedup: %.2fx".format(speedup))
    }
}
