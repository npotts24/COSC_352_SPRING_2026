import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: python app.py <name>")
        sys.exit(1)

    name = sys.argv[1]
    print(f"Hello World {name}")

if __name__ == "__main__":
    main()
