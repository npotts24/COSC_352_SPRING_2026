import sys
from html.parser import HTMLParser
import csv


class TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False
        self.current_row = []
        self.table_data = []

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.in_table = True
        elif tag == "tr" and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag in ("td", "th") and self.in_row:
            self.in_cell = True
            self.cell_data = ""

    def handle_data(self, data):
        if self.in_cell:
            self.cell_data += data.strip()

    def handle_endtag(self, tag):
        if tag in ("td", "th"):
            self.current_row.append(self.cell_data)
            self.in_cell = False
        elif tag == "tr" and self.in_row:
            if self.current_row:
                self.table_data.append(self.current_row)
            self.in_row = False
        elif tag == "table":
            self.in_table = False


def html_table_to_csv(input_html, output_csv):
    parser = TableParser()

    with open(input_html, "r", encoding="utf-8") as f:
        parser.feed(f.read())

    with open(output_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(parser.table_data)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python parse_table.py <input.html> <output.csv>")
        sys.exit(1)

    html_table_to_csv(sys.argv[1], sys.argv[2])
