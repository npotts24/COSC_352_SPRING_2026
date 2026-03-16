import sys

if len(sys.argv) < 2:
    print("Usage: python hello.py <name>")
else:
    name = sys.argv[1]
    print(f"Hello World {name}")


