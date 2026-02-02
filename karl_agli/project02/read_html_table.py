#!/usr/bin/env python3
# Project 2 - HTML Table Parser
# Reads tables from webpages and saves them as CSV

import sys
import csv
import re
from html.parser import HTMLParser
from urllib.request import urlopen
from urllib.error import URLError

class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.current_table = []
        self.current_row = []
        self.current_cell = ''
        self.in_table = False
        self.in_row = False
        self.in_cell = False
    
    def handle_starttag(self, tag, attrs):
        if tag == 'table':
            self.in_table = True
            self.current_table = []
        elif tag == 'tr' and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag in ('td', 'th') and self.in_row:
            self.in_cell = True
            self.current_cell = ''
    
    def handle_endtag(self, tag):
        if tag == 'table' and self.in_table:
            if self.current_table:
                self.tables.append(self.current_table)
            self.in_table = False
            self.current_table = []
        elif tag == 'tr' and self.in_row:
            if self.current_row:
                self.current_table.append(self.current_row)
            self.in_row = False
            self.current_row = []
        elif tag in ('td', 'th') and self.in_cell:
            # clean up whitespace
            text = self.current_cell.strip()
            text = re.sub(r'\s+', ' ', text)
            self.current_row.append(text)
            self.in_cell = False
            self.current_cell = ''
    
    def handle_data(self, data):
        if self.in_cell:
            self.current_cell += data

def get_html(source):
    # check if its a URL or file
    if source.startswith('http://') or source.startswith('https://'):
        try:
            with urlopen(source) as response:
                return response.read().decode('utf-8')
        except URLError as e:
            print(f"Error fetching URL: {e}")
            sys.exit(1)
        except Exception as e:
            print(f"Error: {e}")
            sys.exit(1)
    else:
        # read from file
        try:
            with open(source, 'r', encoding='utf-8') as f:
                return f.read()
        except FileNotFoundError:
            print(f"File not found: {source}")
            sys.exit(1)
        except Exception as e:
            print(f"Error reading file: {e}")
            sys.exit(1)

def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL|FILENAME>")
        print("Example: python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages")
        sys.exit(1)
    
    source = sys.argv[1]
    
    # get the html content
    if source.startswith('http'):
        print(f"Fetching from URL: {source}")
    else:
        print(f"Reading from file: {source}")
    
    html = get_html(source)
    
    # parse tables
    print("Parsing tables...")
    parser = TableParser()
    parser.feed(html)
    
    tables = parser.tables
    print(f"Found {len(tables)} table(s)")
    
    # save each table to csv
    if not tables:
        print("No tables found!")
        return
    
    for i, table in enumerate(tables, 1):
        if not table:
            continue
        
        filename = f"table_{i}.csv"
        
        try:
            with open(filename, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                for row in table:
                    writer.writerow(row)
            print(f"Saved table {i} to {filename} ({len(table)} rows)")
        except Exception as e:
            print(f"Error saving table {i}: {e}")
    
    print("Done!")

if __name__ == '__main__':
    main()
