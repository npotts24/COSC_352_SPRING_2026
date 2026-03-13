import csv

HTML_FILE = "web.html"
CSV_FILE = "languages.csv"

# Remove extra whitespace and normalize spacing in text
def strip_whitespace(text):
    return " ".join(text.split())

# Read the HTML file
with open(HTML_FILE, "r", encoding="utf-8") as f:
    html = f.read()

# Initialize variables to track parsing state
in_row = False
in_cell = False
cell_text = ""
row_cells = []
all_rows = []

# Parse HTML manually by iterating through characters
i = 0
while i < len(html):
    if html[i] == "<":
        # Extract the complete tag
        tag_end = html.find(">", i)
        if tag_end == -1:
            break
        
        tag = html[i:tag_end + 1].lower()
        
        # Start a new table row
        if tag.startswith("<tr"):
            in_row = True
            row_cells = []
        # End the current table row
        elif tag.startswith("</tr"):
            in_row = False
            if row_cells:
                all_rows.append(row_cells)
        # Start a new table cell (td or th)
        elif in_row and tag.startswith("<td") or tag.startswith("<th"):
            in_cell = True
            cell_text = ""
        # End the current table cell
        elif in_row and tag.startswith("</td") or tag.startswith("</th"):
            in_cell = False
            row_cells.append(strip_whitespace(cell_text))
        
        # Move past the tag
        i = tag_end + 1
    # Accumulate text content within a cell
    elif in_cell:
        cell_text += html[i]
        i += 1
    else:
        i += 1

# Write all parsed rows to CSV file
with open(CSV_FILE, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    for row in all_rows:
        writer.writerow(row)

# Print summary message
print(f"Successfully wrote {len(all_rows)} rows to {CSV_FILE}")
