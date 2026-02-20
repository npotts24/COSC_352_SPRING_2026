# Project 2 - HTML Table Parser

Python script that parses HTML tables from webpages and saves them as CSV files.

## How to Run

Basic usage:
```
python read_html_table.py <URL|FILENAME>
```

Example with Wikipedia:
```
python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
```

Or use a local HTML file:
```
python read_html_table.py myfile.html
```

## What it Does

- Reads HTML from a URL or local file
- Finds all tables in the HTML
- Saves each table as a separate CSV file (table_1.csv, table_2.csv, etc.)
- Works with any webpage that has HTML tables

## Requirements

- Python 3.x

## How It Works

The code manually parses HTML by searching for tags using string operations:
- Finds `<table>` and `</table>` tags to extract tables
- Finds `<tr>` and `</tr>` tags for rows
- Finds `<td>` and `<th>` tags for cells
- Strips remaining HTML tags from cell content
- No external parser libraries needed - just basic Python string methods
- Only uses standard library (no pip installs needed)

## Notes

The program will tell you how many tables it found and where it saved them. If there are no tables on the page it will let you know.
