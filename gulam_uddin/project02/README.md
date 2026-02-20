# Project 2 – HTML Table to CSV Parser

## Overview
This project reads and parses HTML tables from a webpage or a local HTML file
and converts the table data into a CSV file that can be loaded into a spreadsheet
application such as Excel or Google Sheets.

The program was designed to work with **any webpage that contains HTML tables**,
not just Wikipedia.

The programming languages table from:
https://en.wikipedia.org/wiki/Comparison_of_programming_languages  
is used as the main example input for this project.

Only **standard Python libraries** are used, as required.

---

## Files in This Project

- `read_html_table.py`  
  Python program that parses HTML tables and outputs a CSV file.

- `csv\`
  Contains sample CSV files related to the project.

- `README.md`  
  Instructions and explanation of the project.

---

## Requirements

- Python 3.x
- No external libraries are required or used

---

## How to Run the Program

The program accepts **either a URL or a local HTML file** as input.

### Example: Run using a URL
```bash
python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
