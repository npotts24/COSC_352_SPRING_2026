#!/usr/bin/env python3
# Project 2 - HTML Table Parser
# Karl Agli
# Parses HTML tables and outputs to CSV

import sys
import csv

# function to get html from url or file
def get_html_content(source):
    # check if its a url or file path
    if source.startswith('http://') or source.startswith('https://'):
        # its a url, need to fetch it
        try:
            import urllib.request
            response = urllib.request.urlopen(source)
            html = response.read().decode('utf-8')
            return html
    except Exception as e:            print("Error: couldn't fetch the url")
        print(f"Error: couldn't fetch the url - {e}")    else:
        # its a file, just read it
        try:
            with open(source, 'r') as f:
                html = f.read()
            return html
    except Exception as e:            print("Error: couldn't read the file")
        print(f"Error: couldn't read the file - {e}")
# function to find all tables in html
def find_tables(html):
    tables = []
    html_lower = html.lower()
    
    # find all table tags
    pos = 0
    while True:
        # look for table start
        start = html_lower.find('<table', pos)
        if start == -1:
            break
            
        # find the matching end tag
        end = html_lower.find('</table>', start)
        if end == -1:
            break
            
        # extract the table
        table_html = html[start:end + 8]
        tables.append(table_html)
        
        pos = end + 8
    
    return tables

# function to parse a single table into rows
def parse_table(table_html):
    rows = []
    table_lower = table_html.lower()
    
    # find all tr tags (table rows)
    pos = 0
    while True:
        tr_start = table_lower.find('<tr', pos)
        if tr_start == -1:
            break
            
        tr_end = table_lower.find('</tr>', tr_start)
        if tr_end == -1:
            break
            
        # extract the row
        row_html = table_html[tr_start:tr_end + 5]
        
        # parse cells in this row
        cells = parse_row(row_html)
        if cells:  # only add if row has cells
            rows.append(cells)
        
        pos = tr_end + 5
    
    return rows

# function to parse cells from a row
def parse_row(row_html):
    cells = []
    row_lower = row_html.lower()
    
    pos = 0
    while True:
        # look for td or th tags
        td_pos = row_lower.find('<td', pos)
        th_pos = row_lower.find('<th', pos)
        
        # find which comes first
        if td_pos == -1 and th_pos == -1:
            break
        elif td_pos == -1:
            cell_start = th_pos
            cell_tag = 'th'
        elif th_pos == -1:
            cell_start = td_pos
            cell_tag = 'td'
        else:
            if td_pos < th_pos:
                cell_start = td_pos
                cell_tag = 'td'
            else:
                cell_start = th_pos
                cell_tag = 'th'
        
        # find the end of opening tag
        tag_end = row_lower.find('>', cell_start)
        if tag_end == -1:
            break
            
        # find closing tag
        close_tag = '</' + cell_tag + '>'
        cell_end = row_lower.find(close_tag, tag_end)
        if cell_end == -1:
            break
            
        # extract cell content
        cell_content = row_html[tag_end + 1:cell_end]
        
        # clean up the content
        cell_text = clean_html(cell_content)
        cells.append(cell_text)
        
        pos = cell_end + len(close_tag)
    
    return cells

# function to clean html tags and extra spaces from text
def clean_html(text):
    # remove any remaining html tags
    clean = ''
    in_tag = False
    
    for char in text:
        if char == '<':
            in_tag = True
        elif char == '>':
            in_tag = False
        elif not in_tag:
            clean += char
    
    # clean up whitespace
    clean = ' '.join(clean.split())

        # decode common html entities
    clean = clean.replace('&nbsp;', ' ')
    clean = clean.replace('&amp;', '&')
    clean = clean.replace('&lt;', '<')
    clean = clean.replace('&gt;', '>')
    clean = clean.replace('&quot;', '"')
    clean = clean.replace('&#39;', "'")
    return clean.strip()

# main function
def main():
    # check command line args
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL|FILENAME>")
        print("Example: python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages")
        sys.exit(1)
    
    source = sys.argv[1]
    
    # tell user what we're doing
    if source.startswith('http'):
        print("Fetching from URL: " + source)
    else:
        print("Reading from file: " + source)
    
    # get the html
    html = get_html_content(source)
    
    # find all tables
    print("Looking for tables...")
    tables = find_tables(html)
    print("Found " + str(len(tables)) + " table(s)")
    
    if len(tables) == 0:
        print("No tables found!")
        return
    
    # save each table to csv
    for i in range(len(tables)):
        table = tables[i]
        rows = parse_table(table)
        
        if not rows:
            continue
        
        filename = "table_" + str(i + 1) + ".csv"
        
        try:
            with open(filename, 'w', newline='') as f:
                writer = csv.writer(f)
                for row in rows:
                    writer.writerow(row)
            
            print("Saved table " + str(i + 1) + " to " + filename + " (" + str(len(rows)) + " rows)")
        except:
            print("Error saving table " + str(i + 1))
    
    print("Done!")

if __name__ == '__main__':
    main()
