import pandas as pd
import urllib.request
from html.parser import HTMLParser
import sys
from pathlib import Path


class Node:
    # Simple tree node for HTML sturcture
    def __init__(self, tag= None, text = ""):
        self.tag = tag
        self.text = text
        self.children = []
    
    def add_child(self, child):
        self.children.append(child)

    
class HTMLTreeBuilder(HTMLParser):
    #Builds a tree from HTML
    def __init__(self):
        super().__init__()
        self.root = Node("document")
        self.stack = [self.root]
    
    def handle_starttag(self, tag, attrs):
        node = Node(tag)
        self.stack[-1].add_child(node)
        self.stack.append(node)

    def handle_endtag(self, tag):
        if len(self.stack) > 1:
            self.stack.pop()

    def handle_data(self, data):
        text = data.strip()
        if text:
            self.stack[-1].add_child(Node(text=text))

def dfs_extract_tables(node, tables):
    #Depth first search traversal to extract table data
    if node.tag == "table":
        table = []
        collect_rows(node, table)
        tables.append(table)
    
    for child in node.children:
        dfs_extract_tables(child, tables)

def collect_rows(node, table):
    #collects rows from a table 
    for child in node.children:
        if child.tag == "tr":
            row = extract_cells(child)
            if row:
                table.append(row)
        collect_rows(child, table)

def extract_cells(row_node):
    #extracts cell data from a table row td/th
    cells = []
    for child in row_node.children:
        if child.tag in ("td", "th"):
            cell_text = collect_text(child)
            cells.append(cell_text)
    return cells

def collect_text(node):
    #recursively collects text from a node
    text = node.text
    for child in node.children:
        text += " " + collect_text(child)
    return text.strip()

def load_html(source):
    #loads HTML from URL or a file
    if source.startswith("http://") or source.startswith("https://"):
        req = urllib.request.Request(
            source, 
            headers = {"User-Agent": "Mozilla/5.0 (compatible; COSC352Bot/1.0)"}
                                     )
        with urllib.request.urlopen(req) as response:
            return response.read().decode("utf-8", errors = "ignore")
    else:
        return Path(source).read_text(encoding = "utf-8", errors = "ignore")
    
def main():
    if len(sys.argv) < 2:
        print("Usage: python table_to_DFS_to_CSV.py <URL or HTML file>")
        sys.exit(1)
    
    html = load_html(sys.argv[1])

    parser = HTMLTreeBuilder()
    parser.feed(html)

    tables = []

    dfs_extract_tables(parser.root, tables)
    for i, table in enumerate(tables):
        df = pd.DataFrame(table)
        df.to_csv(f"table_{i+1}.csv", index = False, header = False)
        filename = f"table_{i+1}.csv"
        print(F"Saved table {i+1} to {filename}")

if __name__ == "__main__":
    main()

