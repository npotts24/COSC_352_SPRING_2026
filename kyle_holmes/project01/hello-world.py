import sys

if len(sys.argv) > 1:
    name = sys.argv[1]
    print(f"Hello World! I mean... Hello {name}!")
else:
    print("Error! No additional arguments provided.")

