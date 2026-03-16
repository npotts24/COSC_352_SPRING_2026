# Baltimore Homicide Histogram (2025)

## Statistic Chosen
Distribution of victim ages for 2025.

## Why This Is Interesting
Age distribution reveals which demographic groups are most affected by violent crime.

## Cleaning Decisions
- Extracted age using regex from victim string
- Removed entries without valid ages
- Grouped ages into 10-year bins

## How to Run

Make sure Docker is installed.

Run:

./run.sh

The script will:
- Scrape data
- Parse ages
- Print tabular histogram
- Save histogram image
