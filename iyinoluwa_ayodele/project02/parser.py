import csv

# ---------------------------------
# SIMPLE HTML TABLE EXTRACTOR
# ---------------------------------
# Reads an HTML file, walks through it character-by-character,
# and extracts table rows (<tr>) and cells (<td>/<th>).
#
# No external libraries. Designed for clarity.
# ---------------------------------

INPUT_HTML = "webpage.html"
OUTPUT_CSV = "languages.csv"


def clean_text(s):
    """Remove extra whitespace inside cell text."""
    return " ".join(s.split())


# Load HTML file
with open(INPUT_HTML, "r", encoding="utf-8") as file:
    page = file.read()

# Parser state
in_row = False
in_cell = False

cell_buffer = ""
row_buffer = []
table_rows = []

pos = 0
while pos < len(page):
    char = page[pos]

    # Detect HTML tag
    if char == "<":
        close = page.find(">", pos)
        if close == -1:
            break  # stop if HTML is broken

        tag_text = page[pos + 1:close].strip().lower()

        # ----- ROW START -----
        if tag_text.startswith("tr"):
            in_row = True
            row_buffer = []

        # ----- ROW END -----
        elif tag_text.startswith("/tr"):
            in_row = False
            if row_buffer:
                table_rows.append(row_buffer)

        # ----- CELL START -----
        elif in_row and (tag_text.startswith("td") or tag_text.startswith("th")):
            in_cell = True
            cell_buffer = ""

        # ----- CELL END -----
        elif in_row and (tag_text.startswith("/td") or tag_text.startswith("/th")):
            in_cell = False
            row_buffer.append(clean_text(cell_buffer))

        pos = close + 1
        continue

    # Collect visible text inside table cells
    if in_cell:
        cell_buffer += char

    pos += 1


# Write extracted table to CSV
with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as csvfile:
    writer = csv.writer(csvfile)
    for r in table_rows:
        writer.writerow(r)

print(f"Finished! {len(table_rows)} rows written to {OUTPUT_CSV}")
