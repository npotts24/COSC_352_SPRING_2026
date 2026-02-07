import sys

# Check if at least one argument (after the script name) is provided 
if len(sys.argv) > 1:
    name = sys.argv[1]
    print(f"Hello World! Actually I meant hello {name}!")
else:
    print("ERROR: No additional arguments provided.")


