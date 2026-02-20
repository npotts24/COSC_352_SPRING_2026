'''
Ran in the CLI

Can just paste the command below

How to use: python programming-languages.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages

also works with other links such as https://www.boxofficemojo.com/intl/?ref_=bo_nb_hm_tab

'''

import sys
import csv
import os
from html.parser import HTMLParser
from urllib.request import urlopen, Request
from html.parser import HTMLParser
from pathlib import Path




#-------------class to aprse the table -------------#
class wiki_parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_table = False
        self.in_row = False
        self.in_cell = False
        self.current_row = []
        self.table = []
        self.current_data = ""

#-------------identifies start tags for rows, tables, and data -------------#
    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.in_table = True

        if self.in_table and tag == "tr":
            self.in_row = True
            self.current_row = []

        if self.in_row and (tag == "td" or tag == "th"):
            self.in_cell = True
            self.current_data = ""

#-------------removes whitespace-------------#
    def handle_data(self, data):
        if self.in_cell:
            self.current_data += data.strip()

#-------------identifies end tags for rows, tables, and data -------------#
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

#------------- reads the html file from source, this case its live from the website via URL -------------#
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


#----------------main function where proper input is verified, the URL gets read, and the data gets stores into a table---------------------#
def main():
    if len(sys.argv) != 2:
        print("How to use: python programming-languages.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages")
        return

    source = sys.argv[1]
    
    html_content = read_html(source)
    
    parser = wiki_parser()
    
    parser.feed(html_content)
    
    #-------------writes data that was stores in parser table to a csv file-------------#

    with open("output.csv", "w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        for row in parser.table:
            writer.writerow(row)

    print("Table data stored in output.csv")


#-------------script execution safeguard-------------#
if __name__ == "__main__":
    main()