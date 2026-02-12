#!/usr/bin/env python3
"""
HTML Table to CSV Converter

This program reads HTML content (from a URL or local file) and extracts all tables,
converting them to CSV format. It uses only Python standard library features.

Author: Claude
Date: February 2026
"""

import sys
import csv
import re
from html.parser import HTMLParser
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError


class TableParser(HTMLParser):
    """
    Custom HTML parser that extracts table data from HTML content.
    
    This parser tracks when it enters/exits table elements and captures
    all cell data (th and td elements) along with their structure.
    """
    
    def __init__(self):
        super().__init__()
        self.tables = []  # List of all tables found
        self.current_table = []  # Current table being parsed
        self.current_row = []  # Current row being parsed
        self.current_cell = []  # Current cell content being captured
        self.in_table = False
        self.in_row = False
        self.in_cell = False
        self.in_header = False
    
    def handle_starttag(self, tag, attrs):
        """Handle opening HTML tags"""
        if tag == 'table':
            self.in_table = True
            self.current_table = []
        elif tag == 'tr' and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag in ['td', 'th'] and self.in_row:
            self.in_cell = True
            self.current_cell = []
            if tag == 'th':
                self.in_header = True
    
    def handle_endtag(self, tag):
        """Handle closing HTML tags"""
        if tag == 'table' and self.in_table:
            if self.current_table:  # Only add non-empty tables
                self.tables.append(self.current_table)
            self.in_table = False
            self.current_table = []
        elif tag == 'tr' and self.in_row:
            if self.current_row:  # Only add non-empty rows
                self.current_table.append(self.current_row)
            self.in_row = False
            self.current_row = []
        elif tag in ['td', 'th'] and self.in_cell:
            # Join all text content and clean it up
            cell_text = ''.join(self.current_cell).strip()
            # Remove extra whitespace and normalize
            cell_text = re.sub(r'\s+', ' ', cell_text)
            self.current_row.append(cell_text)
            self.in_cell = False
            self.in_header = False
            self.current_cell = []
    
    def handle_data(self, data):
        """Handle text content within tags"""
        if self.in_cell:
            self.current_cell.append(data)


def fetch_html(source):
    """
    Fetch HTML content from a URL or read from a local file.
    
    Args:
        source: URL string (http/https) or local file path
    
    Returns:
        String containing HTML content
    
    Raises:
        FileNotFoundError: If local file doesn't exist
        URLError: If URL cannot be accessed
    """
    # Check if source is a URL
    if source.startswith('http://') or source.startswith('https://'):
        try:
            # Add user agent to avoid being blocked by some websites
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            req = Request(source, headers=headers)
            with urlopen(req, timeout=10) as response:
                # Decode response, handling different encodings
                content = response.read()
                try:
                    return content.decode('utf-8')
                except UnicodeDecodeError:
                    return content.decode('latin-1')
        except HTTPError as e:
            print(f"HTTP Error {e.code}: {e.reason}", file=sys.stderr)
            sys.exit(1)
        except URLError as e:
            print(f"URL Error: {e.reason}", file=sys.stderr)
            sys.exit(1)
        except Exception as e:
            print(f"Error fetching URL: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        # Read from local file
        try:
            with open(source, 'r', encoding='utf-8') as f:
                return f.read()
        except FileNotFoundError:
            print(f"Error: File '{source}' not found", file=sys.stderr)
            sys.exit(1)
        except UnicodeDecodeError:
            # Try with different encoding if UTF-8 fails
            try:
                with open(source, 'r', encoding='latin-1') as f:
                    return f.read()
            except Exception as e:
                print(f"Error reading file: {e}", file=sys.stderr)
                sys.exit(1)


def write_tables_to_csv(tables, base_filename='output'):
    """
    Write extracted tables to CSV file(s).
    
    Args:
        tables: List of tables, where each table is a list of rows
        base_filename: Base name for output CSV file(s)
    
    Returns:
        List of created CSV filenames
    """
    created_files = []
    
    if not tables:
        print("No tables found in the HTML content", file=sys.stderr)
        return created_files
    
    for idx, table in enumerate(tables):
        if not table:  # Skip empty tables
            continue
        
        # Generate filename for this table
        if len(tables) == 1:
            filename = f"{base_filename}.csv"
        else:
            filename = f"{base_filename}_table_{idx + 1}.csv"
        
        try:
            with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.writer(csvfile)
                
                # Write all rows
                for row in table:
                    writer.writerow(row)
            
            created_files.append(filename)
            print(f"Created: {filename} ({len(table)} rows, {len(table[0]) if table else 0} columns)")
        
        except Exception as e:
            print(f"Error writing {filename}: {e}", file=sys.stderr)
    
    return created_files


def print_usage():
    """Print usage information"""
    print("Usage: python read_html_table.py <URL|FILENAME> [output_name]")
    print()
    print("Arguments:")
    print("  URL|FILENAME  : Web URL (http/https) or local HTML file path")
    print("  output_name   : (Optional) Base name for output CSV file(s)")
    print("                  Default: 'output'")
    print()
    print("Examples:")
    print("  python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages")
    print("  python read_html_table.py downloaded_page.html")
    print("  python read_html_table.py page.html programming_languages")
    print()
    print("Output:")
    print("  - If one table found: <output_name>.csv")
    print("  - If multiple tables: <output_name>_table_1.csv, <output_name>_table_2.csv, etc.")


def main():
    """Main program entry point"""
    # Check command line arguments
    if len(sys.argv) < 2 or sys.argv[1] in ['-h', '--help', 'help']:
        print_usage()
        sys.exit(0)
    
    source = sys.argv[1]
    output_name = sys.argv[2] if len(sys.argv) > 2 else 'output'
    
    print(f"Reading HTML from: {source}")
    
    # Fetch HTML content
    html_content = fetch_html(source)
    print(f"HTML content loaded ({len(html_content)} characters)")
    
    # Parse tables from HTML
    parser = TableParser()
    parser.feed(html_content)
    
    print(f"Found {len(parser.tables)} table(s)")
    
    # Write tables to CSV
    created_files = write_tables_to_csv(parser.tables, output_name)
    
    if created_files:
        print("\nSuccess! CSV files created:")
        for filename in created_files:
            print(f"  - {filename}")
    else:
        print("\nNo CSV files were created", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
