import sys
import csv
from html.parser import HTMLParser
from urllib.request import urlopen, Request



class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False

        self.tables = []          # list of tables
        self.current_table = []   # current table
        self.current_row = []     # current row
        self.current_cell = ""    # current cell text

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


def read_html(source):
    if source.startswith("http://") or source.startswith("https://"):
        request = Request(
            source,
            headers={"User-Agent": "Mozilla/5.0"}
        )
        with urlopen(request) as response:
            return response.read().decode("utf-8")
    else:
        with open(source, "r", encoding="utf-8") as file:
            return file.read()


def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL|FILENAME>")
        return

    source = sys.argv[1]

    html_content = read_html(source)

    parser = TableParser()
    parser.feed(html_content)

    if not parser.tables:
        print("No tables found.")
        return

    # Write the FIRST table to CSV
    with open("output.csv", "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile)
        for row in parser.tables[0]:
            writer.writerow(row)

    print("CSV file created: output.csv")


if __name__ == "__main__":
    main()
