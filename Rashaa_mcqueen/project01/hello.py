import sys
def main():
   if len(sys.argv)<2:
     print('Usage:python hello.py<name>')
     return
  name = sys.argv[1]
  print(f'Hello World{name}')

if __name__=="__main__":
  main() 
