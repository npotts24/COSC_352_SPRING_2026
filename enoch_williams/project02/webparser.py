"""
web.py

Reads a LOCAL HTML file, extracts ONLY table data, removes extra whitespace,
and writes ALL tables into ONE CSV file.

Uses ONLY Python standard library modules.

HOW TO RUN:
-----------
python web.py web.html
"""

import sys
import csv
from html.parser import HTMLParser


class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.current_table = []
        self.current_row = []
        self.current_cell = ""
        self.in_table = False
        self.in_row = False
        self.in_cell = False

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.in_table = True
            self.current_table = []

        elif tag == "tr" and self.in_table:
            self.in_row = True
            self.current_row = []

        elif tag in ("td", "th") and self.in_table:
            self.in_cell = True
            self.current_cell = ""

    def handle_data(self, data):
        if self.in_cell:
            clean = " ".join(data.split())
            self.current_cell += clean

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.in_cell:
            self.current_row.append(self.current_cell.strip())
            self.in_cell = False

        elif tag == "tr" and self.in_row:
            if self.current_row:
                self.current_table.append(self.current_row)
            self.in_row = False

        elif tag == "table" and self.in_table:
            if self.current_table:
                self.tables.append(self.current_table)
            self.in_table = False


def load_html_file(filename):
    with open(filename, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def write_single_csv(tables):
    with open("tables_output.csv", "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)

        for t_index, table in enumerate(tables, start=1):
            # Table separator
            writer.writerow([f"TABLE {t_index}"])
            for row in table:
                writer.writerow(row)
            writer.writerow([])  # Blank line between tables

    print("Wrote tables_output.csv")


def main():
    if len(sys.argv) != 2:
        print("Usage: python web.py <html_file>")
        sys.exit(1)

    html = load_html_file(sys.argv[1])

    parser = TableParser()
    parser.feed(html)

    if not parser.tables:
        print("No tables found.")
        return

    write_single_csv(parser.tables)
    print(f"Extracted {len(parser.tables)} table(s).")


if __name__ == "__main__":
    main()
