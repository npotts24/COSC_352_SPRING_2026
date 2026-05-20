import java.io.File
import kotlin.system.measureTimeMillis
import kotlinx.coroutines.*

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

fun main(args: Array<String>) = runBlocking {
    if (args.isEmpty()) {
        println("Usage: kotlinc PrimeCounter.kt -include-runtime -d pc.jar && java -jar pc.jar <file>")
        return@runBlocking
    }

    val nums = File(args[0]).readLines().mapNotNull { it.toIntOrNull() }
    
    // Single-Threaded
    var countST = 0
    val timeST = measureTimeMillis {
        countST = nums.count { isPrime(it) }
    }

    // Multi-Threaded
    val cores = Runtime.getRuntime().availableProcessors()
    val chunkSize = (nums.size + cores - 1) / cores
    var countMT = 0
    
    val timeMT = measureTimeMillis {
        val jobs = (0 until cores).map { i ->
            async(Dispatchers.Default) {
                val start = i * chunkSize
                val end = minOf(start + chunkSize, nums.size)
                if (start >= nums.size) 0
                else (start until end).count { isPrime(nums[it]) }
            }
        }
        countMT = jobs.awaitAll().sum()
    }

    println("[Single-Threaded]\n  Primes: $countST\n  Time: ${timeST}.00 ms")
    println("[Multi-Threaded] ($cores threads)\n  Primes: $countMT\n  Time: ${timeMT}.00 ms")
}