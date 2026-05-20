import sys

if len(sys.argv) > 1:
    name = sys.argv[1]
    print(f"Hello World {name}")
else:
    print("Error : No name provided.")

