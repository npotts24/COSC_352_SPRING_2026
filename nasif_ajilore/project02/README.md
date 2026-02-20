# HTML Table Parser

A Python program that extracts HTML tables from URLs or local files and exports them to CSV format.

## Features

- **Flexible input**: Accept either a URL or a local HTML file path
- **Multiple tables**: Automatically extracts all tables from a single HTML document
- **Standard library only**: No external dependencies required (uses built-in `html.parser`, `urllib`, `csv`)
- **Smart parsing**: Handles complex HTML structures, HTML entities, and nested elements
- **CSV export**: Creates properly formatted CSV files that can be opened in Excel or other spreadsheet applications
- **Clear feedback**: Provides detailed output about what was found and what was saved

## Requirements

- Python 3.6 or higher
- No external libraries required (uses only Python standard library)

## Installation

No installation needed! The script only uses Python's built-in modules.

## Usage

```bash
python read_html_table.py <URL|FILENAME>
```

### Arguments

- `<URL|FILENAME>`: Either a full URL (starting with `http://` or `https://`) or a path to a local HTML file

### Examples

#### From a URL

```bash
python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
```

This will fetch the page and extract all tables, creating CSV files like:
- `Comparison_of_programming_languages_table_1.csv`
- `Comparison_of_programming_languages_table_2.csv`
- etc.

#### From a local HTML file

First, save an HTML file (e.g., `page.html`), then run:

```bash
python read_html_table.py page.html
```

This will create CSV files like:
- `page_table_1.csv`
- `page_table_2.csv`
- etc.

## How It Works

1. **Input Detection**: The program checks if the input starts with `http://` or `https://`
   - If yes: Fetches the page from the URL using `urllib`
   - If no: Reads the HTML from a local file

2. **HTML Parsing**: Uses Python's built-in `html.parser.HTMLParser` to parse the HTML
   - Identifies `<table>`, `<tr>`, `<td>`, and `<th>` tags
   - Extracts cell content while handling nested elements

3. **Data Cleaning**: 
   - Removes extra whitespace
   - Handles HTML entities (`&nbsp;`, `&lt;`, etc.)
   - Handles numeric character references (`&#160;`, `&#x20;`, etc.)

4. **CSV Export**: Uses Python's `csv` module to write properly formatted CSV files
   - Each table becomes a separate CSV file
   - Filenames are auto-generated based on input source and table number

## Output

The program generates CSV files in the current directory. The filename format is:

```
{source_name}_table_{number}.csv
```

### Example Output Files

For Wikipedia input:
- `comparison_of_programming_languages_table_1.csv`
- `comparison_of_programming_languages_table_2.csv`

For a local file `data.html`:
- `data_table_1.csv`
- `data_table_2.csv`

## Advantages of This Approach

- **No dependencies to install**: Uses only Python's standard library
- **Portable**: Works on any system with Python 3.6+
- **Flexible**: Works with any HTML page that contains tables
- **Safe**: Doesn't require installing external web scraping libraries
- **Educational**: Clear code structure demonstrates HTML parsing fundamentals

## Limitations

- Only extracts basic table structure (rows and columns)
- Does not handle very complex nested tables or table structures
- Requires internet connection when using URLs
- May not work perfectly with all HTML structures (e.g., tables with complex colspan/rowspan)

## Troubleshooting

### "File not found" Error
- Make sure the HTML file path is correct
- Use the full path if the file is not in the current directory

### "Error fetching URL" Error
- Check your internet connection
- Verify the URL is correct and accessible
- Some websites may block automated access

### Empty CSV Files
- The webpage may not have any tables
- Check the source HTML to confirm tables exist
- Some tables may be created dynamically with JavaScript (which this parser cannot execute)

## Code Structure

- `TableParser`: Custom HTML parser class that extracts table data
- `fetch_html_from_url()`: Retrieves HTML from a URL
- `read_html_from_file()`: Reads HTML from a local file
- `parse_tables()`: Extracts table data from HTML content
- `save_table_to_csv()`: Writes table data to CSV file
- `main()`: Program entry point and flow control


