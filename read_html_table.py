#!/usr/bin/env python3
"""
read_html_table.py

Usage:
    python read_html_table.py <URL|FILENAME>

Reads all HTML <table> elements from the given web page or local HTML file
and writes CSV files:
    table_0.csv, table_1.csv, ...

Only Python standard libraries are used (no external packages).
"""

import urllib.request
import sys
import csv
import html
from html.parser import HTMLParser
from urllib.parse import urlparse
from urllib.request import urlopen


class TableHTMLParser(HTMLParser):
    """
    Simple HTML table parser using only the standard library.

    - Collects all <table> elements found in the HTML.
    - Each table is represented as a list of rows.
    - Each row is a list of cell strings (from <th> or <td>).
    """

    def __init__(self):
        super().__init__()
        self.tables = []          # list of tables; each is list[list[str]]
        self._in_table = False
        self._in_row = False
        self._in_cell = False
        self._current_table = []
        self._current_row = []
        self._current_cell = []

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag == "table":
            # Start a new table
            self._in_table = True
            self._current_table = []
        elif tag == "tr" and self._in_table:
            # Start a new row in the current table
            self._in_row = True
            self._current_row = []
        elif tag in ("td", "th") and self._in_row:
            # Start a new cell in the current row
            self._in_cell = True
            self._current_cell = []

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in ("td", "th") and self._in_cell:
            # Finish current cell
            text = "".join(self._current_cell).strip()
            text = html.unescape(text)
            self._current_row.append(text)
            self._in_cell = False
        elif tag == "tr" and self._in_row:
            # Finish current row
            self._current_table.append(self._current_row)
            self._in_row = False
        elif tag == "table" and self._in_table:
            # Finish current table
            self.tables.append(self._current_table)
            self._in_table = False

    def handle_data(self, data):
        if self._in_cell:
            self._current_cell.append(data)


def load_html(source: str) -> str:
    """
    Load HTML content from a URL or a local file path.
    Adds browser User-Agent to bypass Wikipedia blocks.
    """
    parsed = urlparse(source)
    if parsed.scheme in ("http", "https"):
        req = urllib.request.Request(source)
        req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36')
        with urllib.request.urlopen(req) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            return resp.read().decode(charset, errors="replace")
    else:
        with open(source, "r", encoding="utf-8", errors="replace") as f:
            return f.read()


def write_tables_to_csv(tables):
    """
    Write each table to a CSV file: table_0.csv, table_1.csv, ...
    """
    for idx, table in enumerate(tables):
        filename = f"table_{idx}.csv"
        with open(filename, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            for row in table:
                writer.writerow(row)
        print(f"Wrote {filename}")


def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL|FILENAME>")
        sys.exit(1)

    source = sys.argv[1]
    html_text = load_html(source)

    parser = TableHTMLParser()
    parser.feed(html_text)

    if not parser.tables:
        print("No <table> elements found.")
        sys.exit(0)

    write_tables_to_csv(parser.tables)


if __name__ == "__main__":
    main()
