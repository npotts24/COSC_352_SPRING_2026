import sys

def echo():
    if len(sys.argv) > 1:
        name = sys.argv[1]
        print(f"Hello World! Hey {name}, I see you!" )
    else:
        print(f"Please try again with a name." )
 
echo()