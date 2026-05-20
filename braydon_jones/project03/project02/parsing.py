import csv
import urllib.request

site = "https://en.wikipedia.org/wiki/Comparison_of_programming_languages"

# Adds User-Agent to get past site's urllib block
agent = urllib.request.Request(site, headers = {"User-Agent": "Mozilla/5.0"})
# Reads table
page = urllib.request.urlopen(agent)
language = page.read()
# Turns data into string for item to be appended to
data = language.decode('utf-8')
# Parses the data into a stack
parsed = []
# Establishes that nothing is under table yet
table = False
# For loop that says if table is true, put the line into the parsed stack
for line in data.splitlines():
    if "<table" in line:
        table = True 

    if "</table>" in line and table:
        parsed.append(line)
        break

    if table:
        parsed.append(line)

# Creates csv file parsed items will be placed into
filename = "parsed.csv"
#Convert to csv
with open("parsed.csv",'w', newline = '') as f:
    writer=csv.writer(f)
    for line in parsed:
        writer.writerow([line])

