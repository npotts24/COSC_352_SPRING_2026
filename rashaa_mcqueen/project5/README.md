# Baltimore City Homicide Data Analysis

## Overview

This project scrapes the 2025 Baltimore City homicide data from:
https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html

The script parses messy HTML tables, extracts structured data, and generates a histogram showing the distribution of victim ages.

---

## Chosen Statistic: Distribution of Victim Ages

I chose to analyze the distribution of victim ages because it reveals which demographic groups are most affected by homicide. 

Age distribution helps identify whether violence disproportionately impacts younger individuals, which can inform prevention efforts and policy decisions.

---

## Data Cleaning Decisions

- Extracted the first HTML table from the blog page
- Cleaned column names using `make.names()`
- Extracted age values using regular expressions
- Converted age values to numeric
- Removed rows with missing age values
- Binned ages into 5-year intervals for histogram visualization

---

## Output

The script:

- Prints a tabular histogram of age ranges and counts to stdout
- Saves a histogram image as `histogram.png`

---

## How to Run

Make sure Docker is installed.

Then run:
