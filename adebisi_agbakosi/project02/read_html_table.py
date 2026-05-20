import sys
import urllib.request
import csv
from html.parser import HTMLParser

class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_td = False
        self.in_th = False
        self.rows = []
        self.current_row = []

    def handle_starttag(self, tag, attrs):
        if tag == 'tr': self.current_row = []
        elif tag == 'td': self.in_td = True
        elif tag == 'th': self.in_th = True

    def handle_data(self, data):
        if self.in_td or self.in_th:
            self.current_row.append(data.strip())

    def handle_endtag(self, tag):
        if tag == 'td': self.in_td = False
        elif tag == 'th': self.in_th = False
        elif tag == 'tr': self.rows.append(self.current_row)

def main():
    # Usage: python read_html_table.py <URL|FILENAME>
    source = sys.argv[1]
    
    # Logic to read from URL or local File
    if source.startswith('http'):
        with urllib.request.urlopen(source) as response:
            html = response.read().decode('utf-8')
    else:
        with open(source, 'r', encoding='utf-8') as f:
            html = f.read()

    parser = TableParser()
    parser.feed(html)

    # Write to CSV
    with open('programming_languages.csv', 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerows(parser.rows)

if __name__ == "__main__":
    main()