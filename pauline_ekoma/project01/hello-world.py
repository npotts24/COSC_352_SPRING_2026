import sys

#the script name is always the first element (index 0)
if len(sys.argv)>1:
    name = sys.argv[1]
    print(f"Hello World {name}!!")
else:
    print("ERROR: Try again.")