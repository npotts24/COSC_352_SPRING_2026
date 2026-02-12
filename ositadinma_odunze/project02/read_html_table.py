import csv
import sys
from urllib.request import urlopen, Request


def read_html(source):
    """
    Read HTML content from a file or URL.
    
    Args:
        source: Either a filename or URL
        
    Returns:
        HTML content as string
    """
    # Check if source is a URL
    if source.startswith('http://') or source.startswith('https://'):
        print(f"Fetching from URL: {source}")
        req = Request(source, headers={'User-Agent': 'Mozilla/5.0'})
        with urlopen(req) as response:
            html = response.read().decode('utf-8')
            print("Successfully fetched HTML")
            return html
    else:
        # Read from file
        print(f"Reading from file: {source}")
        with open(source, 'r', encoding='utf-8') as f:
            html = f.read()
            print("Successfully read HTML file")
            return html


def parse_table(html):
    """
    Parse HTML tables using a stack-based approach.
    Manually processes the HTML character by character.
    
    Args:
        html: HTML content as string
        
    Returns:
        List of rows, where each row is a list of cell values
    """
    stack = []      # Stack to track open tags
    rows = []       # All rows found in table
    row = []        # Current row being built
    cell = ""       # Current cell content
    i = 0           # Position in HTML string
    in_table = False
    
    while i < len(html):
        # Found start of a tag
        if html[i] == '<':
            i += 1
            tag = ""
            
            # Read the tag name
            while i < len(html) and html[i] != '>' and html[i] != ' ':
                tag += html[i]
                i += 1
            
            # Skip to end of tag (handle attributes)
            while i < len(html) and html[i] != '>':
                i += 1
            
            # Skip the closing '>' of the tag
            if i < len(html) and html[i] == '>':
                i += 1
            
            # Process table tags
            if tag == "table":
                in_table = True
                stack.append("table")
                
            elif tag == "/table":
                in_table = False
                if stack and stack[-1] == "table":
                    stack.pop()
                    
            # Process row tags
            elif tag == "tr" and in_table:
                stack.append("tr")
                row = []
                
            elif tag == "/tr" and in_table:
                if stack and stack[-1] == "tr":
                    stack.pop()
                    if row:  # Only add non-empty rows
                        rows.append(row)
                        
            # Process cell tags (td or th)
            elif (tag == "td" or tag == "th") and in_table:
                stack.append("td")
                cell = ""
                
            elif (tag == "/td" or tag == "/th") and in_table:
                if stack and stack[-1] == "td":
                    stack.pop()
                    # Clean up the cell content and add to row
                    cell_text = cell.strip()
                    # Replace multiple spaces with single space
                    cell_text = ' '.join(cell_text.split())
                    row.append(cell_text)
                    cell = ""
        
        # Regular character - add to cell if we're inside a cell
        else:
            if stack and stack[-1] == "td":
                cell += html[i]
            i += 1
    
    return rows


def write_csv(rows, output_file):
    """
    Write table rows to CSV file.
    
    Args:
        rows: List of rows (each row is a list of values)
        output_file: Name of output CSV file
    """
    if not rows:
        print("No data to write")
        return
    
    print(f"Writing {len(rows)} rows to {output_file}")
    
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        for row in rows:
            writer.writerow(row)
    
    print(f"Successfully created {output_file}")


def main():
    """Main program execution."""
    
    # Check command line arguments
    if len(sys.argv) < 2:
        print("Usage: python read_html_table.py <filename|URL>")
        print("\nExamples:")
        print("  python read_html_table.py ProgrammingLanguages.html")
        print("  python read_html_table.py https://example.com/page.html")
        sys.exit(1)
    
    source = sys.argv[1]
    
    try:
        # Step 1: Read the HTML
        html = read_html(source)
        
        # Step 2: Parse tables
        print("Parsing HTML tables...")
        rows = parse_table(html)
        
        print(f"Found {len(rows)} rows")
        
        if not rows:
            print("No table data found")
            sys.exit(1)
        
        # Step 3: Generate output filename
        if source.startswith('http://') or source.startswith('https://'):
            output_file = 'output.csv'
        else:
            # Use input filename as base
            base = source.rsplit('.', 1)[0]
            output_file = f'{base}_output.csv'
        
        # Step 4: Write to CSV
        write_csv(rows, output_file)
        
        # Print summary
        print("\n" + "="*50)
        print(f"Source: {source}")
        print(f"Rows extracted: {len(rows)}")
        if rows:
            print(f"Columns: {len(rows[0])}")
        print(f"Output: {output_file}")
        print("="*50)
        
    except FileNotFoundError:
        print(f"Error: File not found - {source}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()