#!/usr/bin/env python3
import sys
import csv
import urllib.request
from html.parser import HTMLParser

class TableHTMLParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.current_table = []
        self.current_row = []
        self.in_table = False
        self.in_cell = False
        self.cell_data = ""

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.in_table = True
            self.current_table = []
        elif tag == "tr" and self.in_table:
            self.current_row = []
        elif tag in ("td", "th") and self.in_table:
            self.in_cell = True
            self.cell_data = ""

    def handle_data(self, data):
        if self.in_cell:
            self.cell_data += data.strip() + " "

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.in_table:
            self.in_cell = False
            self.current_row.append(self.cell_data.strip())
        elif tag == "tr" and self.in_table:
            if self.current_row:
                self.current_table.append(self.current_row)
        elif tag == "table":
            self.in_table = False
            if self.current_table:
                self.tables.append(self.current_table)

def read_html(source):
    if source.startswith("http"):
        with urllib.request.urlopen(source) as r:
            return r.read().decode("utf-8", errors="ignore")
    else:
        with open(source, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()

def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL_or_HTML_file>")
        sys.exit(1)

    html = read_html(sys.argv[1])
    parser = TableHTMLParser()
    parser.feed(html)

    for i, table in enumerate(parser.tables):
        with open(f"table_{i+1}.csv", "w", newline="", encoding="utf-8") as out:
            writer = csv.writer(out)
            for row in table:
                writer.writerow(row)
        print(f"Saved table_{i+1}.csv")

if __name__ == "__main__":
    main()
