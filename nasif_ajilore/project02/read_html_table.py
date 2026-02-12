#!/usr/bin/env python3
"""
HTML Table Parser - Extract tables from HTML files or URLs to CSV

This program reads HTML content from either a local file or a URL,
extracts all tables found in the HTML, and exports them to CSV files.
It uses only Python standard library features (no external dependencies).

"""

import sys
import os
import csv
import re
from html.parser import HTMLParser
from urllib.request import urlopen
from urllib.error import URLError
from pathlib import Path


class TableParser(HTMLParser):
    """
    Custom HTML parser that extracts table data from HTML content.
    
    This parser identifies table elements and extracts rows and cells,
    handling both <th> (header) and <td> (data) cells.
    """
    
    def __init__(self):
        """Initialize the parser and set up data structures."""
        super().__init__()
        self.tables = []  # List to store all tables found
        self.current_table = []  # Current table being parsed
        self.current_row = []  # Current row being parsed
        self.in_table = False  # Flag to track if we're inside a table
        self.in_row = False  # Flag to track if we're inside a row
        self.in_cell = False  # Flag to track if we're inside a cell
        self.current_cell = ""  # Content of current cell
        self.skip_cell = False  # Flag to skip certain elements
        
    def handle_starttag(self, tag, attrs):
        """Handle opening HTML tags."""
        if tag == "table":
            self.in_table = True
            self.current_table = []
        elif tag in ("tr",) and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag in ("td", "th") and self.in_row:
            self.in_cell = True
            self.current_cell = ""
        elif tag == "script":
            # Skip content inside script tags
            self.skip_cell = True
        elif tag == "style":
            # Skip content inside style tags
            self.skip_cell = True
            
    def handle_endtag(self, tag):
        """Handle closing HTML tags."""
        if tag == "table" and self.in_table:
            if self.current_table:  # Only add non-empty tables
                self.tables.append(self.current_table)
            self.current_table = []
            self.in_table = False
        elif tag == "tr" and self.in_row:
            if self.current_row:  # Only add non-empty rows
                self.current_table.append(self.current_row)
            self.current_row = []
            self.in_row = False
        elif tag in ("td", "th") and self.in_cell:
            # Clean up the cell content
            clean_cell = self.current_cell.strip()
            # Remove extra whitespace
            clean_cell = re.sub(r'\s+', ' ', clean_cell)
            self.current_row.append(clean_cell)
            self.current_cell = ""
            self.in_cell = False
        elif tag == "script":
            self.skip_cell = False
        elif tag == "style":
            self.skip_cell = False
            
    def handle_data(self, data):
        """Handle text data between tags."""
        if self.in_cell and not self.skip_cell:
            self.current_cell += data
            
    def handle_entityref(self, name):
        """Handle HTML entities like &nbsp; &lt; etc."""
        if self.in_cell and not self.skip_cell:
            # Convert common entities
            entities = {
                'nbsp': ' ',
                'lt': '<',
                'gt': '>',
                'amp': '&',
                'quot': '"',
                'apos': "'"
            }
            self.current_cell += entities.get(name, f'&{name};')
            
    def handle_charref(self, name):
        """Handle numeric character references like &#160; or &#x20;"""
        if self.in_cell and not self.skip_cell:
            if name.startswith('x'):
                char = chr(int(name[1:], 16))
            else:
                char = chr(int(name))
            self.current_cell += char


def fetch_html_from_url(url):
    """
    Fetch HTML content from a URL.
    
    Args:
        url (str): The URL to fetch
        
    Returns:
        str: The HTML content
        
    Raises:
        URLError: If the URL cannot be accessed
    """
    try:
        print(f"Fetching HTML from URL: {url}")
        # Create a request with a User-Agent header to avoid 403 Forbidden errors
        # Many websites (like Wikipedia) block requests without a proper User-Agent
        from urllib.request import Request
        req = Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'})
        response = urlopen(req, timeout=10)
        html_content = response.read().decode('utf-8', errors='ignore')
        print(f"Successfully fetched {len(html_content)} characters from URL")
        return html_content
    except URLError as e:
        raise Exception(f"Error fetching URL '{url}': {e}")
    except Exception as e:
        raise Exception(f"Unexpected error fetching URL '{url}': {e}")


def read_html_from_file(filepath):
    """
    Read HTML content from a local file.
    
    Args:
        filepath (str): Path to the HTML file
        
    Returns:
        str: The HTML content
        
    Raises:
        FileNotFoundError: If the file doesn't exist
    """
    try:
        print(f"Reading HTML from file: {filepath}")
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            html_content = f.read()
        print(f"Successfully read {len(html_content)} characters from file")
        return html_content
    except FileNotFoundError:
        raise Exception(f"File not found: '{filepath}'")
    except Exception as e:
        raise Exception(f"Error reading file '{filepath}': {e}")


def get_html_content(input_source):
    """
    Determine if input is a URL or file path and fetch HTML accordingly.
    
    Args:
        input_source (str): Either a URL or file path
        
    Returns:
        str: The HTML content
    """
    # Check if it's a URL (starts with http:// or https://)
    if input_source.startswith(('http://', 'https://')):
        return fetch_html_from_url(input_source)
    else:
        # Treat it as a file path
        return read_html_from_file(input_source)


def parse_tables(html_content):
    """
    Parse HTML content and extract all tables.
    
    Args:
        html_content (str): The HTML content to parse
        
    Returns:
        list: A list of tables, where each table is a list of rows,
              and each row is a list of cell values
    """
    parser = TableParser()
    try:
        parser.feed(html_content)
    except Exception as e:
        print(f"Warning: Error while parsing HTML: {e}")
    
    return parser.tables


def save_table_to_csv(table, output_filename):
    """
    Save a single table to a CSV file.
    
    Args:
        table (list): A table (list of rows, each row is a list of cells)
        output_filename (str): Path to the output CSV file
        
    Returns:
        bool: True if successful, False otherwise
    """
    try:
        with open(output_filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerows(table)
        return True
    except Exception as e:
        print(f"Error saving CSV file '{output_filename}': {e}")
        return False


def get_output_filename(input_source, table_index):
    """
    Generate an output CSV filename based on input source and table number.
    
    Args:
        input_source (str): The input URL or file path
        table_index (int): The index of the table (0-based)
        
    Returns:
        str: The output filename
    """
    # Extract a base name from the input
    if input_source.startswith(('http://', 'https://')):
        # Extract domain and page name from URL
        # Example: https://en.wikipedia.org/wiki/Comparison_of_programming_languages
        # -> comparison_of_programming_languages
        path = input_source.split('/')[-1]
        if not path or path == '':
            path = 'webpage'
        base_name = path.replace('.html', '').replace('?', '_').replace('&', '_')
    else:
        # Use the filename without extension
        base_name = Path(input_source).stem
    
    # Create filename: basename_table_1.csv, basename_table_2.csv, etc.
    return f"{base_name}_table_{table_index + 1}.csv"


def main():
    """
    Main program entry point.
    Parses command-line arguments and processes the HTML input.
    """
    # Check command-line arguments
    if len(sys.argv) < 2:
        print("Usage: python read_html_table.py <URL|FILENAME>")
        print()
        print("Description:")
        print("  Reads HTML tables from a URL or local file and exports them to CSV.")
        print()
        print("Examples:")
        print("  python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages")
        print("  python read_html_table.py page.html")
        print()
        sys.exit(1)
    
    input_source = sys.argv[1]
    
    try:
        # Step 1: Get HTML content
        print("\n" + "="*60)
        print("HTML Table Parser")
        print("="*60)
        
        html_content = get_html_content(input_source)
        
        # Step 2: Parse tables from HTML
        print("\nParsing HTML for tables...")
        tables = parse_tables(html_content)
        
        if not tables:
            print("No tables found in the HTML content.")
            sys.exit(0)
        
        print(f"Found {len(tables)} table(s)")
        
        # Step 3: Save each table to a CSV file
        print("\nExporting tables to CSV files...")
        saved_count = 0
        
        for i, table in enumerate(tables):
            output_filename = get_output_filename(input_source, i)
            rows_count = len(table)
            cols_count = max(len(row) for row in table) if table else 0
            
            print(f"\nTable {i + 1}:")
            print(f"  Dimensions: {rows_count} rows × {cols_count} columns")
            print(f"  Output file: {output_filename}")
            
            if save_table_to_csv(table, output_filename):
                print(f"  Status: ✓ Successfully saved")
                saved_count += 1
            else:
                print(f"  Status: ✗ Failed to save")
        
        print("\n" + "="*60)
        print(f"Summary: {saved_count}/{len(tables)} tables exported successfully")
        print("="*60 + "\n")
        
    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
