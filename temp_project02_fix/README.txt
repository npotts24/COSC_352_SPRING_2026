Project: Read HTML Table and Export to CSV

Description:
This Python program reads HTML from either a URL or a local HTML file,
finds the largest table in the page, and writes it to a CSV file.

Standard library only:
This program only uses Python standard library modules:
csv, html, os, re, sys, urllib.request, html.parser, urllib.parse

How to run:
python3 read_html_table.py <URL|FILENAME>

Examples:
python3 read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
python3 read_html_table.py Comparison_of_programming_languages.html

Output:
The program creates a CSV file in the current directory.

Files included:
- read_html_table.py
- Comparison_of_programming_languages.csv
- README.txt


