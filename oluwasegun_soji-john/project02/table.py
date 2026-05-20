"""This is a normal python file that can be run in the CLI. You run this by using "Python3 table.py" command"""


import csv



HTML_FILE = "web.html"
CSV_FILE = "languages.csv"


def tidy(text: str) -> str:
    """
    Cleans up text by collapsing extra whitespace:
    - "  hello   world " -> "hello world"
    """
    return " ".join(text.split())


def read_tag(html: str, start_index: int):
    """
    Given an HTML string and an index where html[start_index] == '<',
    return (tag_text_lower, tag_end_index).

    Example:
      html = "...<tr>..."
      start_index at '<' returns ("<tr>", index_of_>)
    """
    end_index = html.find(">", start_index)
    if end_index == -1:
        return None, -1  # malformed HTML
    tag_text = html[start_index:end_index + 1].lower()
    return tag_text, end_index


# Read HTML from disk (you already have the file)
with open(HTML_FILE, "r", encoding="utf-8") as f:
    html = f.read()

# These are state variables
in_row = False
in_cell = False

cell_chars = []      # characters collected for ONE cell
row_cells = []       # list of cells for ONE row
all_rows = []        # list of all rows found

skip_tag = False     # True when we are inside <...> (we ignore characters there)

# Loop through HTML by index
i = 0
for i in range(len(html)):
    ch = html[i]

    # If we see a '<', we are starting a tag
    if ch == "<":
        tag, end_idx = read_tag(html, i)
        if tag is None:
            break  # malformed HTML, stop

        # ---- Row start / end ----
        if tag.startswith("<tr"):
            in_row = True
            row_cells = []

        elif tag.startswith("</tr"):
            in_row = False
            # store only non-empty rows
            if row_cells:
                all_rows.append(row_cells)

        # ---- Cell start / end ----
        elif in_row and (tag.startswith("<td") or tag.startswith("<th")):
            in_cell = True
            cell_chars = []

        elif in_row and (tag.startswith("</td") or tag.startswith("</th")):
            in_cell = False
            cell_text = tidy("".join(cell_chars))
            row_cells.append(cell_text)

        # Jump the loop index forward by skipping the inside of the tag
        # (We can't change the for-loop index directly, so we use skip_tag)
        skip_tag = True
        continue

    # If the previous character started a tag, we need to ignore until '>'
    if skip_tag:
        if ch == ">":
            skip_tag = False
        continue

    # Collect only text that appears inside a cell
    if in_cell:
        cell_chars.append(ch)

# Write results to CSV
with open(CSV_FILE, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerows(all_rows)

print(f"Export complete: {len(all_rows)} rows written to {CSV_FILE}")