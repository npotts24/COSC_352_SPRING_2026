import sys
import csv
import os
import html
from urllib.request import urlopen, Request
from html.parser import HTMLParser

# Check the project directory for the ReadMe file to know how to run this program. 
# The program should be run from the command line with a URL or local file path as an argument.


# ---------- HTML PARSER CLASS ---------
# HTML parser that accumulates complete cell text before appending to tables.
class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        # list of tables; each table is list of rows
        self.tables = []   
        # rows for the currently-parsed table         
        self.current_table = []    
        # cells for the current row 
        self.current_row = []    
        # list of text fragments for the current cell   
        self.current_cell = []      
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
            self.current_cell = []

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.in_cell:
            # finish current cell: join fragments and unescape entities
            cell_text = html.unescape(''.join(self.current_cell)).strip()
            self.current_row.append(cell_text)
            self.current_cell = []
            self.in_cell = False
        elif tag == 'tr' and self.in_row:
            # finish current row (append even if empty to preserve structure)
            self.in_row = False
            self.current_table.append(self.current_row)
            self.current_row = []
        elif tag == 'table' and self.in_table:
            # finish table
            self.in_table = False
            # Only append non-empty tables (allow header-only tables)
            if any(self.current_table):
                self.tables.append(self.current_table)
            self.current_table = []

    def handle_data(self, data):
        if self.in_cell:
            self.current_cell.append(data)


# --------- HELPER FUNCTION TO READ FROM URL OR FILE ---------
def read_input_source(path_or_url):
    # Return HTML string read from a URL or local file path.
    if path_or_url.startswith(('http://', 'https://')):
        req = Request(path_or_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urlopen(req) as response:
            return response.read().decode('utf-8', errors='replace')
    else:
        with open(path_or_url, 'r', encoding='utf-8', errors='replace') as f:
            return f.read()

# --------- MAIN PROGRAM --------- 
def web_page_parser():
    if len(sys.argv) <= 1:
        print('Please try again with a url or local html file path.')
        return

    source = sys.argv[1]
    try:
        html_text = read_input_source(source)
    except Exception as e:
        print(f'Error reading {source}: {e}')
        return

    parser = TableParser()
    parser.feed(html_text)

    if not parser.tables:
        print('No <table> elements found in the source.')
        return

    # Write each table to CSV
    for i, table in enumerate(parser.tables, start=1):
        filename = f'CSV_File_{i}.csv'
        try:
            with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.writer(csvfile)
                for row in table:
                    writer.writerow(row)
            print(f'Wrote table {i} to {filename}')
        except Exception as e:
            print(f'Error writing {filename}: {e}')

# Call the main function to run the program
web_page_parser()