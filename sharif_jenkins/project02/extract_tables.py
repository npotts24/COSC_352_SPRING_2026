#!/usr/bin/env python3
"""
extract_tables.py

Reads a URL or local HTML file, extracts all HTML tables, and writes each table
to a CSV file.

- Uses ONLY Python standard library
- Works with any HTML page that contains <table> elements
- Outputs one CSV file per table

Usage:
  python3 extract_tables.py <url-or-local-file>
"""

# Standard library imports
import sys               # command-line arguments and exit handling
import os                # filesystem utilities (not strictly required but safe)
import csv               # CSV file writing
import urllib.request    # HTTP fetching for URLs
import html              # HTML entity unescaping
from html.parser import HTMLParser  # Built-in HTML parser


class TableParser(HTMLParser):
    """
    Custom HTML parser that extracts tables from HTML.

    Data structure:
      self.tables = [
          [ ['cell11', 'cell12'], ['cell21', 'cell22'] ],   # table 1
          [ ['cell11', 'cell12'] ]                           # table 2
      ]
    """

    def __init__(self):
        super().__init__()

        # Final result: list of tables
        self.tables = []

        # State flags to track where we are in the HTML document
        self.in_table = False
        self.in_tr = False
        self.in_td = False

        # Working buffers for the currently parsed table
        self.current_table = None
        self.current_row = None

        # Temporary buffer to accumulate text inside a table cell
        self.cell_chunks = []

    def handle_starttag(self, tag, attrs):
        """
        Called by HTMLParser whenever a start tag (<tag>) is encountered.
        """
        tag = tag.lower()

        # Detect the start of a table
        if tag == 'table':
            self.in_table = True
            self.current_table = []

        # Detect the start of a table row
        elif tag == 'tr' and self.in_table:
            self.in_tr = True
            self.current_row = []

        # Detect the start of a table cell (data or header)
        elif tag in ('td', 'th') and self.in_tr:
            self.in_td = True
            self.cell_chunks = []

    def handle_endtag(self, tag):
        """
        Called by HTMLParser whenever an end tag (</tag>) is encountered.
        """
        tag = tag.lower()

        # End of a table cell
        if tag in ('td', 'th') and self.in_td:
            # Join collected text fragments
            text = ''.join(self.cell_chunks).strip()

            # Decode HTML entities (&nbsp;, &#160;, etc.)
            text = html.unescape(' '.join(text.split()))

            # Append cell text to current row
            self.current_row.append(text)

            # Reset cell state
            self.in_td = False
            self.cell_chunks = []

        # End of a table row
        elif tag == 'tr' and self.in_tr:
            # Append the completed row to the table
            if self.current_row is None:
                self.current_row = []
            self.current_table.append(self.current_row)

            # Reset row state
            self.current_row = None
            self.in_tr = False

        # End of a table
        elif tag == 'table' and self.in_table:
            # Save completed table
            self.tables.append(self.current_table)

            # Reset table state
            self.current_table = None
            self.in_table = False

    def handle_data(self, data):
        """
        Called when plain text data is encountered.
        Only capture text if we are inside a table cell.
        """
        if self.in_td:
            self.cell_chunks.append(data)

    def handle_entityref(self, name):
        """
        Handles named HTML entities like &nbsp; or &amp;
        """
        if self.in_td:
            self.cell_chunks.append(f"&{name};")

    def handle_charref(self, name):
        """
        Handles numeric HTML entities like &#160;
        """
        if self.in_td:
            self.cell_chunks.append(f"&#{name};")


def fetch_input(path_or_url):
    """
    Load HTML content from either:
    - a URL (http/https)
    - a local file on disk
    """
    if path_or_url.startswith(('http://', 'https://')):
        # Fetch HTML from the web
        with urllib.request.urlopen(path_or_url) as resp:
            charset = resp.headers.get_content_charset() or 'utf-8'
            return resp.read().decode(charset, errors='replace')
    else:
        # Read HTML from a local file
        with open(path_or_url, 'r', encoding='utf-8', errors='replace') as f:
            return f.read()


def write_tables(tables, out_prefix='table'):
    """
    Write extracted tables to CSV files.

    Each table is written as:
      table_1.csv
      table_2.csv
      ...
    """
    for i, table in enumerate(tables, start=1):
        filename = f"{out_prefix}_{i}.csv"

        # Determine the maximum number of columns in the table
        maxcols = max((len(row) for row in table), default=0)

        with open(filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)

            for row in table:
                # Pad rows so all have the same number of columns
                padded_row = row + [''] * (maxcols - len(row))
                writer.writerow(padded_row)

        print(f"Wrote {filename} ({len(table)} rows, {maxcols} columns)")


def main():
    """
    entry point.
    """
    # Validate command-line arguments
    if len(sys.argv) != 2:
        print("Usage: python3 extract_tables.py <url-or-local-file>")
        sys.exit(1)

    source = sys.argv[1]

    # Load HTML content
    html_text = fetch_input(source)

    # Parse HTML
    parser = TableParser()
    parser.feed(html_text)

    # Write output
    if not parser.tables:
        print("No tables found.")
    else:
        write_tables(parser.tables)

if __name__ == '__main__':
    main()