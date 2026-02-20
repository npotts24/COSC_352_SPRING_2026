# Quick Start Guide

## Installation
No installation required! Just Python 3.x.

## Run the Program

### Option 1: Direct from URL (Wikipedia Programming Languages)
```bash
python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
```

### Option 2: Download HTML first, then parse
```bash
# Download the Wikipedia page
curl -o languages.html "https://en.wikipedia.org/wiki/Comparison_of_programming_languages"

# Parse the downloaded file
python read_html_table.py languages.html programming_languages
```

### Option 3: Test with included example
```bash
python read_html_table.py test_example.html test_output
cat test_output_table_1.csv
```

## Expected Output
The program will create one or more CSV files:
- `output.csv` (single table) or
- `output_table_1.csv`, `output_table_2.csv`, etc. (multiple tables)

## Viewing the CSV
```bash
# On Linux/Mac
cat output.csv

# Or open in a spreadsheet program
# Excel, Google Sheets, LibreOffice Calc, etc.
```

## Common Use Cases

### Parse any Wikipedia table
```bash
python read_html_table.py "https://en.wikipedia.org/wiki/List_of_countries_by_GDP" gdp_data
```

### Parse a local HTML file
```bash
python read_html_table.py my_data.html my_output
```

## Troubleshooting

### Program doesn't work?
1. Check Python version: `python --version` (needs 3.x)
2. Try using `python3` instead of `python`
3. Verify file/URL exists

### No tables found?
The HTML might not contain actual `<table>` elements. Modern websites sometimes use CSS to style divs as tables.

### Need help?
```bash
python read_html_table.py --help
```
