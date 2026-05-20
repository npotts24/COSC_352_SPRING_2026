# read_html_table.py


# Example:
#   python3 read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages

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
        self.current_row = []
        self.table = []
        self.current_data = ""

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.in_table = True

        if self.in_table and tag == "tr":
            self.in_row = True
            self.current_row = []

        if self.in_row and (tag == "td" or tag == "th"):
            self.in_cell = True
            self.current_data = ""

    def handle_data(self, data):
        if self.in_cell:
            self.current_data += data.strip()

    def handle_endtag(self, tag):
        if tag == "table":
            self.in_table = False

        if tag == "tr" and self.in_row:
            if self.current_row:
                self.table.append(self.current_row)
            self.in_row = False

        if (tag == "td" or tag == "th") and self.in_cell:
            self.current_row.append(self.current_data)
            self.in_cell = False


def read_html(source):
  
    if source.startswith("http://") or source.startswith("https://"):
        req = Request(
            source,
            headers={"User-Agent": "Mozilla/5.0"}
        )
        response = urlopen(req)
        return response.read().decode("utf-8")
    else:
       
        with open(source, "r", encoding="utf-8") as file:
            return file.read()


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 read_html_table.py <URL or HTML file>")
        return

    source = sys.argv[1]

    
    html_content = read_html(source)

    
    parser = TableParser()
    parser.feed(html_content)

    
    with open("output.csv", "w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        for row in parser.table:
            writer.writerow(row)

    print("Table data written to output.csv")


if __name__ == "__main__":
    main()
