import sys
import csv
from html.parser import HTMLParser
from urllib.request import urlopen, Request



class TableToCSVParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False

        self.rows = []
        self.current_row = []
        self.current_cell_text = ""

        self.found_first_table = False

    def handle_starttag(self, tag, attrs):
        if tag == "table" and not self.found_first_table:
            self.in_table = True
            self.found_first_table = True

        if self.in_table and tag == "tr":
            self.in_row = True
            self.current_row = []

        if self.in_table and self.in_row and (tag == "td" or tag == "th"):
            self.in_cell = True
            self.current_cell_text = ""

    def handle_data(self, data):
        if self.in_table and self.in_cell:
            self.current_cell_text += data

    def handle_endtag(self, tag):
        if self.in_table and self.in_row and (tag == "td" or tag == "th"):
            self.in_cell = False
            clean = " ".join(self.current_cell_text.split())
            self.current_row.append(clean)

        if self.in_table and tag == "tr":
            self.in_row = False
            if len(self.current_row) > 0:
                self.rows.append(self.current_row)

        if tag == "table" and self.in_table:
            self.in_table = False


def read_input_as_html(source: str) -> str:
    if source.startswith("http://") or source.startswith("https://"):
        req = Request(source, headers={"User-Agent": "Mozilla/5.0"})
        with urlopen(req) as response:
            return response.read().decode("utf-8", errors="ignore")

    with open(source, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


    # Otherwise treat it like a local filename
    with open(source, "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URLorHTMLfilename>")
        sys.exit(1)

    source = sys.argv[1]
    html_text = read_input_as_html(source)

    parser = TableToCSVParser()
    parser.feed(html_text)

    if len(parser.rows) == 0:
        print("ERROR: No table rows found.")
        sys.exit(1)

    output_file = "languages.csv"
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for row in parser.rows:
            writer.writerow(row)

    print(f"Wrote {len(parser.rows)} rows to {output_file}")


if __name__ == "__main__":
    main()
