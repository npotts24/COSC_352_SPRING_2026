import csv
import sys
import urllib.request
from html.parser import HTMLParser

class SimpleTableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.is_cell = False
        self.current_row = []
        self.all_rows = []

    def handle_starttag(self, tag, attrs):
        if tag == "td" or tag == "th":
            self.is_cell = True

    def handle_data(self, data):
        if self.is_cell:
            clean_data = data.strip()
            if clean_data:
                self.current_row.append(clean_data)

    def handle_endtag(self, tag):
        if tag == "td" or tag == "th":
            self.is_cell = False
        if tag == "tr":
            if self.current_row:
                self.all_rows.append(self.current_row)
            self.current_row = []

def save_to_csv(data, filename="programming_languages.csv"):
    if not data:
        return
    
    row_lengths = [len(row) for row in data]
    if not row_lengths:
        return
    
    most_common_length = max(set(row_lengths), key=row_lengths.count)
    
    cleaned_data = []
    for row in data:
        if len(row) != most_common_length:
            continue
        if all(cell.strip() in ('', ',', '","', '[', ']') for cell in row):
            continue
        
        cleaned_data.append(row)
    
    if not cleaned_data:
        print("No valid data to save after filtering.")
        return

    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerows(cleaned_data)
    
    print(f"Data successfully saved to {filename} ({len(cleaned_data)} rows)")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <URL>")
        sys.exit(1)

    url = sys.argv[1]
    
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url

    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        
        with urllib.request.urlopen(req) as response:
            raw_html = response.read().decode('utf-8')

        parser = SimpleTableParser()
        parser.feed(raw_html)

        if parser.all_rows:
            save_to_csv(parser.all_rows)
        else:
            print("No table data found to save.")

        print(f"Successfully found {len(parser.all_rows)} rows of data.")
        for row in parser.all_rows[:5]:
            print(row)

    except Exception as e:
        print(f"Test failed: {e}")