# Project 05: Baltimore Homicide Histogram (R + Docker)

## What I Chose
I chose to build a histogram of **victim ages** from the Baltimore homicide lists.

I used:
- 2025 list (required)
- 2024 list (extra context)

I picked age because it quickly shows which age ranges are most affected.

## How My Script Works
1. Scrapes table rows from the blog pages.
2. Parses each row into:
   - case number
   - date
   - victim name
   - victim age
3. Cleans the data (drops missing/invalid ages).
4. Builds a 5-year age-bin histogram.
5. Prints the histogram table to stdout.
6. Saves a plot image as `victim_age_histogram.png`.

## Assumptions / Cleaning
- A valid homicide row starts with a case value like `001` or `XXX`, then a date like `01/09/25`.
- Age is taken from the first number after the victim name.
- Ages outside normal human range (<=0 or >=110) are removed.
- Duplicates are removed by `(year, case_number)`.

## Run
From this folder:

```bash
./run.sh
```

This builds the Docker image and runs the script.  
The table prints directly in the terminal.
