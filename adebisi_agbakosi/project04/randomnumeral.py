import random

def generate_numbers(filename="numbers.txt", count=1000000):
    print(f"Generating {count} numbers in {filename}...")
    with open(filename, "w") as f:
        for _ in range(count):
            # Mix of small, large, and negative numbers
            num = random.randint(-100, 1000000)
            f.write(f"{num}\n")
    print("Done.")

if __name__ == "__main__":
    generate_numbers()