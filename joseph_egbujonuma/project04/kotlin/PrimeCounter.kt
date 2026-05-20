import java.io.File
import java.text.DecimalFormat
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.Future

fun isPrime(n: Long): Boolean {
    //if statements for primality checkers on the numbers
    if (n <= 1L) return false
    if (n <= 3L) return true
    if (n % 2L == 0L || n % 3L == 0L) return false

    var i = 5L
    while (i * i <= n) {
        if (n % i == 0L || n % (i + 2L) == 0L) return false
        i += 6L
    }
    return true
}

fun readNumbers(path: String): LongArray {
    val file = File(path)
    val list = ArrayList<Long>(1_000_000)

    //reading the file line by line for memory stability when parsing
    file.forEachLine { line ->
        val s = line.trim()
        if (s.isEmpty()) return@forEachLine
        val v = s.toLongOrNull()
        if (v != null) list.add(v)
    }

    val arr = LongArray(list.size)
    for (i in list.indices) arr[i] = list[i]
    return arr
}

//the single threaded approach
fun countPrimesSingle(nums: LongArray): Int {
    var count = 0
    for (v in nums) if (isPrime(v)) count++
    return count
}

//the multithreaded approach
fun countPrimesMulti(nums: LongArray, threads: Int): Int {
    val pool = Executors.newFixedThreadPool(threads)
    return try {
        val n = nums.size
        val chunkSize = (n + threads - 1) / threads

        val tasks = ArrayList<Callable<Int>>()
        var start = 0
        while (start < n) {
            val end = minOf(start + chunkSize, n)
            val s = start
            val e = end
            tasks.add(Callable {
                var local = 0
                for (i in s until e) if (isPrime(nums[i])) local++
                local
            })
            start = end
        }

        val futures: List<Future<Int>> = pool.invokeAll(tasks)
        var total = 0
        for (f in futures) total += f.get()
        total
    } finally {
        pool.shutdown()
    }
}

fun usage() {
    println("Usage: java -jar kotlin/PrimeCounter.jar <path-to-numbers.txt>")
    println("Example: java -jar kotlin/PrimeCounter.jar numbers.txt")
}

fun msSince(startNs: Long): Double = (System.nanoTime() - startNs) / 1_000_000.0

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        usage()
        return
    }

    val path = args[0]
    val file = File(path)
    if (!file.exists() || !file.canRead()) {
        println("Cannot read file: $path")
        usage()
        return
    }

    val nums = try {
        readNumbers(path)
    } catch (e: Exception) {
        println("Error reading file: ${e.message}")
        usage()
        return
    }

    val threads = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)

    val sStart = System.nanoTime()
    val singleCount = countPrimesSingle(nums)
    val singleMs = msSince(sStart)

    val mStart = System.nanoTime()
    val multiCount = countPrimesMulti(nums, threads)
    val multiMs = msSince(mStart)

    val dfCount = DecimalFormat("#,##0")
    val speedup = if (multiMs > 0.0) singleMs / multiMs else Double.POSITIVE_INFINITY

    println("File: ${file.name} (${dfCount.format(nums.size)} numbers)")
    println()
    println("[Single-Threaded]")
    println("  Primes found: ${dfCount.format(singleCount)}")
    println("  Time: ${"%.1f".format(singleMs)} ms")
    println()
    println("[Multi-Threaded] ($threads threads)")
    println("  Primes found: ${dfCount.format(multiCount)}")
    println("  Time: ${"%.1f".format(multiMs)} ms")
    println()
    println("Speedup: ${"%.2f".format(speedup)}x")
}
