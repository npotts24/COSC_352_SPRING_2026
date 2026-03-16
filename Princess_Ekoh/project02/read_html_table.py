#!/usr/bin/env python3
"""
read_html_table.py

Reads HTML from either:
1. a URL
2. a local HTML file

Parses all tables found in the HTML, chooses the largest table,
and writes that table to a CSV file.

Usage:
    python3 read_html_table.py <URL|FILENAME>
"""

import csv
import html
import os
import re
import sys
import urllib.request
from html.parser import HTMLParser
from urllib.parse import urlparse


def clean_text(text):
    text = html.unescape(text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def safe_filename_from_source(source):
    if source.startswith("http://") or source.startswith("https://"):
        parsed = urlparse(source)
        base = os.path.basename(parsed.path.strip("/"))
        if not base:
            base = "output"
    else:
        base = os.path.splitext(os.path.basename(source))[0]

    base = re.sub(r"[^A-Za-z0-9._-]+", "_", base)
    if not base:
        base = "output"
    return base + ".csv"


def read_source(source):
    if source.startswith("http://") or source.startswith("https://"):
        req = urllib.request.Request(
            source,
            headers={
                "User-Agent": "Mozilla/5.0"
            }
        )
        with urllib.request.urlopen(req) as response:
            encoding = response.headers.get_content_charset() or "utf-8"
            return response.read().decode(encoding, errors="replace")
    else:
        with open(source, "r", encoding="utf-8", errors="replace") as f:
            return f.read()



class TableHTMLParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.in_table = 0
        self.current_table = None
        self.current_row = None
        self.current_cell = None
        self.capture_cell_text = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)

        if tag == "table":
            self.in_table += 1
            if self.in_table == 1:
                self.current_table = []

        elif tag == "tr" and self.in_table >= 1:
            if self.in_table == 1:
                self.current_row = []

        elif tag in ("td", "th") and self.in_table >= 1:
            if self.in_table == 1 and self.current_row is not None:
                colspan = attrs.get("colspan", "1")
                rowspan = attrs.get("rowspan", "1")

                try:
                    colspan = int(colspan)
                except ValueError:
                    colspan = 1

                try:
                    rowspan = int(rowspan)
                except ValueError:
                    rowspan = 1

                self.current_cell = {
                    "text": "",
                    "colspan": max(1, colspan),
                    "rowspan": max(1, rowspan),
                    "header": (tag == "th"),
                }
                self.capture_cell_text = True

        elif tag == "br" and self.capture_cell_text and self.current_cell is not None:
            self.current_cell["text"] += " "

    def handle_data(self, data):
        if self.capture_cell_text and self.current_cell is not None:
            self.current_cell["text"] += data

    def handle_entityref(self, name):
        if self.capture_cell_text and self.current_cell is not None:
            self.current_cell["text"] += html.unescape(f"&{name};")

    def handle_charref(self, name):
        if self.capture_cell_text and self.current_cell is not None:
            self.current_cell["text"] += html.unescape(f"&#{name};")

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.in_table >= 1:
            if self.in_table == 1 and self.current_cell is not None and self.current_row is not None:
                self.current_cell["text"] = clean_text(self.current_cell["text"])
                self.current_row.append(self.current_cell)
                self.current_cell = None
            self.capture_cell_text = False

        elif tag == "tr" and self.in_table >= 1:
            if self.in_table == 1 and self.current_row is not None and self.current_table is not None:
                if self.current_row:
                    self.current_table.append(self.current_row)
                self.current_row = None

        elif tag == "table":
            if self.in_table == 1 and self.current_table is not None:
                if self.current_table:
                    self.tables.append(self.current_table)
                self.current_table = None
            self.in_table -= 1


def expand_table(table):
    expanded = []
    pending_rowspans = {}

    for row in table:
        output_row = []
        col_index = 0

        def flush_pending_until_gap():
            nonlocal col_index, output_row
            while col_index in pending_rowspans:
                remaining, text = pending_rowspans[col_index]
                output_row.append(text)
                remaining -= 1
                if remaining <= 0:
                    del pending_rowspans[col_index]
                else:
                    pending_rowspans[col_index] = [remaining, text]
                col_index += 1

        flush_pending_until_gap()

        for cell in row:
            flush_pending_until_gap()

            text = cell["text"]
            colspan = cell["colspan"]
            rowspan = cell["rowspan"]

            for _ in range(colspan):
                output_row.append(text)
                if rowspan > 1:
                    pending_rowspans[col_index] = [rowspan - 1, text]
                col_index += 1

            flush_pending_until_gap()

        while col_index in pending_rowspans:
            remaining, text = pending_rowspans[col_index]
            output_row.append(text)
            remaining -= 1
            if remaining <= 0:
                del pending_rowspans[col_index]
            else:
                pending_rowspans[col_index] = [remaining, text]
            col_index += 1

        expanded.append(output_row)

    while pending_rowspans:
        output_row = []
        col_index = 0
        while col_index in pending_rowspans:
            remaining, text = pending_rowspans[col_index]
            output_row.append(text)
            remaining -= 1
            if remaining <= 0:
                del pending_rowspans[col_index]
            else:
                pending_rowspans[col_index] = [remaining, text]
            col_index += 1
        expanded.append(output_row)

    max_cols = max((len(r) for r in expanded), default=0)
    return [r + [""] * (max_cols - len(r)) for r in expanded]


def score_table(table_matrix):
    if not table_matrix:
        return -1
    rows = len(table_matrix)
    cols = max((len(r) for r in table_matrix), default=0)
    nonempty = sum(1 for row in table_matrix for cell in row if clean_text(cell))
    return (rows * cols) + nonempty


def find_largest_table(html_text):
    parser = TableHTMLParser()
    parser.feed(html_text)

    if not parser.tables:
        return None

    expanded_tables = [expand_table(t) for t in parser.tables]
    return max(expanded_tables, key=score_table)


def write_csv(table_matrix, output_filename):
    with open(output_filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for row in table_matrix:
            writer.writerow(row)


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 read_html_table.py <URL|FILENAME>")
        sys.exit(1)

    source = sys.argv[1]

    try:
        html_text = read_source(source)
    except Exception as e:
        print(f"Error reading input: {e}")
        sys.exit(1)

    table = find_largest_table(html_text)
    if table is None:
        print("No tables found in the provided HTML.")
        sys.exit(1)

    output_filename = safe_filename_from_source(source)

    try:
        write_csv(table, output_filename)
    except Exception as e:
        print(f"Error writing CSV: {e}")
        sys.exit(1)

    print(f"CSV written to: {output_filename}")
    print(f"Rows: {len(table)}")
    print(f"Columns: {max((len(r) for r in table), default=0)}")


if __name__ == "__main__":
    main()

