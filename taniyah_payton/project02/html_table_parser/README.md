# HTML Table to CSV Converter

A Python program that reads HTML tables from any webpage or local file and converts them to CSV format using only standard library features.

## Author
Claude

## Features
- ✅ Parse tables from any webpage URL
- ✅ Parse tables from local HTML files
- ✅ Uses only Python standard library (no external dependencies)
- ✅ Handles multiple tables on a single page
- ✅ Cleans and normalizes cell data
- ✅ Robust error handling
- ✅ Support for both `<th>` and `<td>` elements

## Requirements
- Python 3.x (tested with Python 3.6+)
- No external libraries required

## Usage

### Basic Syntax
```bash
python read_html_table.py <URL|FILENAME> [output_name]
```

### Arguments
- `URL|FILENAME`: Web URL (starting with http:// or https://) or local HTML file path
- `output_name`: (Optional) Base name for output CSV file(s). Default: 'output'

### Examples

#### Example 1: Parse from Wikipedia URL
```bash
python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
```

#### Example 2: Parse from local HTML file
```bash
python read_html_table.py downloaded_page.html
```

#### Example 3: Specify custom output name
```bash
python read_html_table.py page.html programming_languages
```

#### Example 4: Download HTML first, then parse
```bash
# Download the page (optional)
curl -o languages.html "https://en.wikipedia.org/wiki/Comparison_of_programming_languages"

# Parse the downloaded file
python read_html_table.py languages.html languages_output
```

## Output

### Single Table
If the HTML contains one table:
- Output: `output.csv` (or `<output_name>.csv`)

### Multiple Tables
If the HTML contains multiple tables:
- Output: `output_table_1.csv`, `output_table_2.csv`, etc.
- (or `<output_name>_table_1.csv`, `<output_name>_table_2.csv`, etc.)

## How It Works

1. **Fetch HTML**: Reads from URL or local file
2. **Parse HTML**: Uses Python's built-in `HTMLParser` to find all `<table>` elements
3. **Extract Data**: Captures all rows (`<tr>`) and cells (`<td>`, `<th>`)
4. **Clean Data**: Normalizes whitespace and removes extra formatting
5. **Write CSV**: Outputs clean CSV files using Python's `csv` module

## Code Structure

### Main Components

#### `TableParser` class
Custom HTML parser that extends `HTMLParser`:
- Tracks table/row/cell structure
- Extracts text content from cells
- Handles nested tables gracefully

#### `fetch_html()` function
- Fetches HTML from URLs using `urllib`
- Reads HTML from local files
- Handles encoding issues

#### `write_tables_to_csv()` function
- Writes extracted tables to CSV files
- Handles single and multiple table scenarios
- Uses proper CSV formatting

## Technical Details

### Standard Library Modules Used
- `html.parser.HTMLParser`: HTML parsing
- `urllib.request`: URL fetching
- `csv`: CSV file writing
- `sys`: Command line arguments and error handling
- `re`: Regular expression for text cleaning

### Error Handling
- Invalid URLs or unreachable websites
- Missing local files
- File encoding issues
- Empty tables
- Malformed HTML (gracefully degrades)

## Testing

### Test with Wikipedia Programming Languages Page
```bash
python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
```

Expected output: Multiple CSV files containing comparison tables of programming languages.

### Test with Local File
```bash
# Create a simple test HTML file
echo '<html><body><table><tr><th>Language</th><th>Year</th></tr><tr><td>Python</td><td>1991</td></tr><tr><td>Java</td><td>1995</td></tr></table></body></html>' > test.html

# Parse it
python read_html_table.py test.html test_output

# Check the output
cat test_output.csv
```

## Troubleshooting

### "No tables found"
- Verify the HTML file/URL contains actual `<table>` elements
- Some modern websites use `<div>` elements styled as tables (this program won't capture those)

### "Error fetching URL"
- Check internet connection
- Verify the URL is correct
- Some websites block automated requests (try downloading HTML manually)

### "Unicode errors"
- The program attempts UTF-8 and Latin-1 encoding automatically
- For other encodings, download the file and specify encoding manually

## Limitations

1. **Only parses semantic HTML tables**: Uses actual `<table>` elements, not CSS-styled divs
2. **No JavaScript execution**: Cannot parse dynamically generated tables
3. **Basic cell merging**: Colspan/rowspan attributes are not handled specially
4. **No authentication**: Cannot access pages requiring login

## Git Workflow

### Initialize Repository
```bash
cd html_table_parser
git init
git add .
git commit -m "Initial commit: HTML table to CSV converter"
```

### Add to Existing Repository
```bash
# From your course repository root
git add html_table_parser/
git commit -m "Add HTML table parser assignment"
git push
```

## License

This code is provided as-is for educational purposes.

## Version History

- **v1.0** (February 2026): Initial release
  - Basic table parsing functionality
  - URL and file input support
  - CSV output with multiple table handling
