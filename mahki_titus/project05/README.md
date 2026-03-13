# Baltimore City Homicide Histogram (Dockerized R Analysis)

## Overview
This project scrapes Baltimore City homicide data from Cham's Page and
analyzes victim age distribution for 2025.

## Chosen Statistic
Victim Age Distribution

Age was selected because it provides insight into demographic patterns
of homicide victims and produces a meaningful numeric histogram.

## Data Source
https://chamspage.blogspot.com/

## Methodology
1. Scraped HTML tables using rvest
2. Combined multiple blog tables
3. Extracted victim ages using regex
4. Removed invalid or missing ages
5. Generated histogram bins (10-year ranges)

## Output
- Histogram printed to stdout
- Histogram image saved as histogram.png

## Assumptions & Cleaning
- Ages extracted from victim name column
- Ages outside 0–110 removed
- Missing values ignored

## Running the Project

```bash
./run.sh