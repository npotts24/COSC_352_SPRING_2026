import sys

if len(sys.argv) > 1:
    name = sys.argv[1]
    print(f"whatsup {name}, how's it going?.")
else:
    print("Error: No name provided.")


