#!/usr/bin/env python3
"""
read_html_table.py

Reads ALL tables from an HTML webpage or local HTML file
and outputs them to CSV files.

Usage:
    python read_html_table.py <URL_or_HTML_file>

Example:
    python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
    python read_html_table.py page.html
"""

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
    """Reads HTML from a URL or local file."""
    if source.startswith("http://") or source.startswith("https://"):
        with urllib.request.urlopen(source) as response:
            return response.read().decode("utf-8", errors="ignore")
    else:
        with open(source, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()


def write_tables_to_csv(tables):
    """Writes each table to its own CSV file."""
    for i, table in enumerate(tables):
        filename = f"table_{i+1}.csv"
        with open(filename, "w", newline="", encoding="utf-8") as csvfile:
            writer = csv.writer(csvfile)
            for row in table:
                writer.writerow(row)
        print(f"Saved {filename}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL_or_HTML_file>")
        sys.exit(1)

    source = sys.argv[1]
    html_content = read_html(source)

    parser = TableHTMLParser()
    parser.feed(html_content)

    if not parser.tables:
        print("No tables found.")
        return

    write_tables_to_csv(parser.tables)


if __name__ == "__main__":
    main()
