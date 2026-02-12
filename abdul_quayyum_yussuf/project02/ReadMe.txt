
ReadMe for read_html_table.py Program

Reads HTML tables from a URL or a local HTML file and writes each table
to a CSV file. Uses only Python standard library.

How to use:
  python read_html_table.py <url_or_filepath>

Examples:
  python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
  python read_html_table.py local_copy.html

Notes:
  - The program extracts <table> elements from the HTML. Modern sites
    that render tables with divs will not be captured.
  - Output files: CSV_File_1.csv, CSV_File_2.csv, ... created in cwd.