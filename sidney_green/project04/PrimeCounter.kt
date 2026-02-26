squidney
squidney__
•
on the porch new yorkin

squidney — 4/29/2024 9:47 PM
•    Program #1:
o    addi x5,x0,0x1a: add immediate value at x0 (0) + 1a (26) and place in reg. x5
o    slli x12,x5,24: logical shift left value at x5 by 24 bits and place in reg. x12
o    addi x5,x0,0xff: add immediate value at x0 (0) + ff (255) and place in reg. x5
o    slli x11,x5,16: logical shift left value at x5 by 16 bits and place in reg. x11
o    add x12,x12,x11: add value at x12 + value at x11 and place in reg. x12
o    addi x5,x0,0x52: add immediate value at x0 (0) + 52 (82) and place in reg. x5
o    slli x11,x5,8: logical shift left value at x5 by 8 bits and place in reg. x11
o    add x12,x12,x11: add value at x12 + value at x11 and place in reg. x12
o    addi x12, x12, 0x08: add immediate value at x12 + 08 (8) and place in reg. x12
o    addi x7,x0,4: add immediate value at x0 (0) + 4 (4) and place in reg. x7
o    sw x12,0(x7): store the value at x12 into x7 + 0 offset
o    lw x4,0(x7): load the value stored in x7 + 0 offset and place in reg. x4
Program #2:
o    add x5,x0,x0: add value at x0 (0) + x0 (0) and place in reg. x5
o    addi x11,x0,0x8f5: add immediate value at x0 (0) + 8f5 (-1803) and place in reg. x11
o    sw x11,0(x5): store the value at x11 into x5 + 0 offset
o    lb x12,0(x5): load low byte stored at x5 + 0 offset (f5), place in reg. x12 
o    lb x12,1(x5): load low byte stored at x5 + 1 offset (f8), place in reg. x12
o    lb x12,2(x5): load low byte stored at x5 + 2 offset (ff), place in reg. x12
o    lb x12,3(x5): load low byte stored at x5 + 3 offset (ff), place in reg. x12
o    addi x5,x0,8: add immediate value at x0 (0) + 8 (8) and place in reg. x5
o    addi x11,x0,0xad4: add immediate value at x0 (0) + xad4 (-1324) and place in reg. x11
o    sw x11,0(x5): store the value at x11 in x5 + 0 offset
o    lb x12,0(x5): load low byte stored at x5 + 0 offset (d4), place in reg. x12
o    lb x13,1(x5): load low byte stored at x5 + 1 offset (fa), place in reg. x13
o    lb x14,2(x5): load low byte stored at x5 + 2 offset (ff), place in reg. x14
o    lb x15,3(x5): load low byte stored at x5 + 3 offset (ff), place in reg. x15
Program #3:
o    addi x11,x0,4: add immediate value at x0 (0) + 4 (4) and place in reg. x11
o    addi x12,x0,8: add immediate value at x0 (0) + 8 (8) and place in reg. x12
o    addi x13,x0,3: add immediate value at x0 (0) + 3 (3) and place in reg. x13
o    bne x13,x14,12: if value stored at x13 != value stored at x14, branch 12 bytes (3 instructions) ahead
o    add x10,x11,x12:  add value at x11 (0) + x0 (0) and place in reg. x5 #skipped in example
o    jal x0,8:  Jump 8 bytes (2 instructions ahead) #skipped in example
o    sub x10,x11,x12: sub value at x11 (4) + x12 (8) and place in reg. x10
o    addi x13,x0,3: add immediate value at x0 (0) + 3 (3) and place in reg. x13
prin — 4/29/2024 9:48 PM
do you think he'll notice we copied each other hfhfh
squidney — 4/29/2024 9:48 PM
in program 3, i removed some of the comments
we change the comments and we should be fine i think
prin — 4/29/2024 9:49 PM
coolio
thank you
thats it
?
squidney — 4/29/2024 9:50 PM
yeah
prin — 1/30/2026 3:59 PM
hi
squidney
 started a call that lasted 2 minutes. — 1/30/2026 4:02 PM
prin
 started a call that lasted an hour. — 1/30/2026 5:49 PM
squidney — 1/30/2026 6:02 PM
import sys

if len(sys.argv) > 1:
    name = sys.argv[1]
    print(f"whatsup {name}, how's it going?.")
else:
    print("Error: No name provided.")
FROM python:3.10-slim

WORKDIR /app

COPY hello-world.py /app

ENTRYPOINT ["python", "hello-world.py"]
prin — 4:54 PM
golang
package main

import (
	"bufio"
	"fmt"
	"os"

message.txt
3 KB
java
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

public class PrimeCounter {

    public static boolean isPrime(int n) {
        if (n <= 1) return false;
        if (n <= 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (int i = 5; (long)i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    public static List<Integer> readNumbers(String filePath) throws IOException {
        List<Integer> numbers = new ArrayList<>();
        BufferedReader br = new BufferedReader(new FileReader(filePath));
        String line;

        while ((line = br.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) continue;
            try {
                numbers.add(Integer.parseInt(line));
            } catch (NumberFormatException ignored) {}
        }

        br.close();
        return numbers;
    }

    public static void main(String[] args) throws Exception {

        if (args.length < 1) {
            System.out.println("Usage: java PrimeCounter <file>");
            return;
        }

        String filePath = args[0];
        List<Integer> numbers = readNumbers(filePath);

        System.out.println("File: " + filePath + " (" + numbers.size() + " numbers)\n");

        long startSingle = System.nanoTime();

        int singleCount = 0;
        for (int n : numbers) {
            if (isPrime(n)) singleCount++;
        }

        long endSingle = System.nanoTime();
        double singleTime = (endSingle - startSingle) / 1_000_000.0;

        int threads = Runtime.getRuntime().availableProcessors();
        ExecutorService executor = Executors.newFixedThreadPool(threads);

        int chunkSize = numbers.size() / threads;
        List<Future<Integer>> futures = new ArrayList<>();

        long startMulti = System.nanoTime();

        for (int i = 0; i < threads; i++) {
            int start = i * chunkSize;
            int end = (i == threads - 1) ? numbers.size() : start + chunkSize;

            futures.add(executor.submit(() -> {
                int count = 0;
                for (int j = start; j < end; j++) {
                    if (isPrime(numbers.get(j))) count++;
                }
                return count;
            }));
        }

        int multiCount = 0;
        for (Future<Integer> f : futures) {
            multiCount += f.get();
        }

        long endMulti = System.nanoTime();
        double multiTime = (endMulti - startMulti) / 1_000_000.0;

        executor.shutdown();

        System.out.println("[Single-Threaded]");
        System.out.println("  Primes found: " + singleCount);
        System.out.printf("  Time: %.2f ms\n\n", singleTime);

        System.out.println("[Multi-Threaded] (" + threads + " threads)");
        System.out.println("  Primes found: " + multiCount);
        System.out.printf("  Time: %.2f ms\n\n", multiTime);

        System.out.printf("Speedup: %.2fx\n", singleTime / multiTime);
    }
}

message.txt
4 KB
kotlin
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
... (1 line left)

message.txt
3 KB
run.sh
#!/bin/bash
set -e

FILE=${1:-numbers.txt}

echo "================ JAVA ================"
javac java/PrimeCounter.java
java -cp java PrimeCounter "$FILE"

echo ""
echo "================ KOTLIN ================"
kotlinc kotlin/PrimeCounter.kt -include-runtime -d kotlin.jar
java -jar kotlin.jar "$FILE"

echo ""
echo "================ GO ================"
go run golang/prime_counter.go "$FILE"
read me
Project 4 – Multithreaded Prime Counter
This project counts how many prime numbers appear in a text file (one integer per line) using:
1) a single-threaded approach
2) a multi-threaded approach (threads = CPU cores)

Implemented in:
Java
Kotlin
Go

Requirements
Java (OpenJDK)
Kotlin compiler (kotlinc)
Go

How to Run
From the project04 directory:

```bash
./run.sh numbers.txt
lmfao
numbers.txt
17
4
29
100
7919
1
0
-5
104729
uhhhhh mayb use diff nums
p
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
