import sys
import csv
from html.parser import HTMLParser
from urllib.request import urlopen


class HTMLTableParser(HTMLParser):
    """
    Custom HTML parser to extract tables.
    """

    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False

        self.tables = []
        self.current_table = []
        self.current_row = []
        self.current_data = ""

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        if tag == "table":
            self.in_table = True
            self.current_table = []
        elif tag == "tr" and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag in ("td", "th") and self.in_row:
            self.in_cell = True
            self.current_data = ""

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "table" and self.in_table:
            self.in_table = False
            self.tables.append(self.current_table)
        elif tag == "tr" and self.in_row:
            self.in_row = False
            if self.current_row:
                self.current_table.append(self.current_row)
        elif tag in ("td", "th") and self.in_cell:
            self.in_cell = False
            self.current_row.append(self.current_data.strip())

    def handle_data(self, data):
        if self.in_cell:
            self.current_data += data


def read_html(source):
    """
    Reads HTML from a URL or local file.
    """
    if source.startswith("http://") or source.startswith("https://"):
        with urlopen(source) as response:
            return response.read().decode("utf-8")
    else:
        with open(source, "r", encoding="utf-8") as f:
            return f.read()


def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL_or_HTML_file>")
        sys.exit(1)

    source = sys.argv[1]

    try:
        html = read_html(source)
    except Exception as e:
        print("Error reading input:", e)
        sys.exit(1)

    parser = HTMLTableParser()
    parser.feed(html)

    if not parser.tables:
        print("No tables found.")
        sys.exit(1)

    # Write first table to CSV
    with open("output.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for row in parser.tables[0]:
            writer.writerow(row)

    print("Successfully created output.csv")


if __name__ == "__main__":
    main()
