import urllib.request

import html.parser

import csv

import sys

class ProgrammingLanguageParser(html.parser.HTMLParser):

    """

    A custom HTML parser to extract data from tables.

    It specifically looks for <table>, <tr>, <th>, and <td> tags

    to reconstruct table rows and headers.

    """

    def __init__(self):

        super().__init__()

        self.in_table = False

        self.in_header = False

        self.in_data_row = False

        self.current_header = []

        self.current_row = []

        self.all_data = []

        self.found_target_table = False # Flag to indicate if we've found the programming languages table

    def handle_starttag(self, tag, attrs):

        """

        Called for each start tag (e.g., <p>, <a>, <table>).

        We use this to track when we enter a table and its rows/headers.

        """

        if tag == 'table':

            # assume the first significant table we encounter might be it.

            if not self.found_target_table:

                self.in_table = True

                self.found_target_table = True # Assume the first table is our target

                self.current_header = []

                self.current_row = []

                self.all_data = [] # Reset data for the new table

        elif self.in_table:

            if tag == 'tr':

                self.current_row = [] # Start a new row

                self.in_data_row = True

            elif tag == 'th':

                self.in_header = True

            elif tag == 'td':

                self.in_header = False # Ensure we're not treating td as th

    def handle_endtag(self, tag):

        """

        Called for each end tag (e.g., </p>, </a>, </table>).

        We use this to track when we exit tags and to store completed rows.

        """

        if tag == 'tr' and self.in_table:

            if self.current_row: # Only add if the row has data

                if self.current_header and not self.all_data: # If it's the first row and we have headers

                    self.all_data.append(self.current_header)

                if self.current_row: # Add the current row's data

                    self.all_data.append(self.current_row)

            self.in_data_row = False

            self.current_row = [] # Reset for the next row

        elif tag == 'table':

            self.in_table = False

            self.in_header = False

            # If we found data, we might stop here or look for more tables

            # For this problem, we focus on the first table found.

    def handle_data(self, data):

        """

        Called for each piece of data between tags.

        This is where we capture the actual text content.

        """

        if self.in_table and self.in_data_row:

            cleaned_data = data.strip()

            if cleaned_data: # Only add non-empty data

                # If it's the first row of the table, assume it's headers

                if not self.all_data:

                    self.current_header.append(cleaned_data)

                else:

                    self.current_row.append(cleaned_data)

    def get_data(self):

        """

        Returns the extracted table data.

        The first sublist is treated as the header.

        """

        if not self.all_data:

            return [], []


