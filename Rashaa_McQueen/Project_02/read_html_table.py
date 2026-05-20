import sys
import csv
import urllib.request
from html.parser import HTMLParser


def read_input(source):
    
    if source.startswith("http://") or source.startswith("https://"):
        with urllib.request.urlopen(source) as response:
            return response.read().decode("utf-8")
    else:
        with open(source, "r", encoding="utf-8") as file:
            return file.read()


class TableParser(HTMLParser):
    

    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False

        self.tables = []
        self.current_table = []
        self.current_row = []
        self.current_cell = ""

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.in_table = True
            self.current_table = []
        elif tag == "tr" and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag in ("td", "th") and self.in_row:
            self.in_cell = True
            self.current_cell = ""

    def handle_data(self, data):
        if self.in_cell:
            self.current_cell += data.strip()

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.in_cell:
            self.current_row.append(self.current_cell)
            self.in_cell = False
        elif tag == "tr" and self.in_row:
            if self.current_row:
                self.current_table.append(self.current_row)
            self.in_row = False
        elif tag == "table" and self.in_table:
            if self.current_table:
                self.tables.append(self.current_table)
            self.in_table = False


def write_csv(table, filename):
   
    with open(filename, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        for row in table:
            writer.writerow(row)


def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL|FILENAME>")
        sys.exit(1)

    source = sys.argv[1]
    html = read_input(source)

    parser = TableParser()
    parser.feed(html)

    if not parser.tables:
        print("No tables found.")
        sys.exit(1)

    output_file = "programming_languages.csv"
    write_csv(parser.tables[0], output_file)

    print("Tables found:", len(parser.tables))
    print("CSV file created:", output_file)


if __name__ == "__main__":
    main()
