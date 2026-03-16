# Project 05: Baltimore Homicide Histogram (R + Docker)

## What this project does

This project scrapes Baltimore City homicide lists from Cham's blog for **multiple years (2022-2025)**, parses messy HTML tables into a structured data frame, and creates a histogram of **homicides by month with year overlays**.

Sources used:

- https://chamspage.blogspot.com/2022/01/2022-baltimore-city-homicide-list.html
- https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html
- https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html
- https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html

## Chosen statistic

I used the **distribution of homicides by month, overlaid by year (2022-2025)** because it reveals seasonal concentration patterns and whether those patterns are consistent or changing year-to-year.

## Cleaning and parsing assumptions

- The page can contain irregular table formatting, so the script:
  - Reads all HTML tables
  - Promotes the first row to headers when it looks like a header row
  - Normalizes column names to machine-friendly names
- The script attempts to identify and normalize key fields including age, date, method, camera presence, and case-closed status when available.
- If an explicit age column exists, it is used; otherwise age is extracted from victim/name text with regex.
- Ages outside 0-120 are dropped as invalid in supporting summaries.
- Date parsing is required for the monthly histogram; if date values cannot be parsed, the script fails clearly.
- If a yearly page cannot be scraped, that year is skipped with an informative message.

## Outputs

When run, the script:

1. Prints a tabular histogram to stdout (terminal)
2. Saves a plot image: `homicide_month_histogram_2022_2025.png`
3. Prints supporting median age by year (where valid age values are available)

## How to run

From this folder:

```bash
./run.sh
```

This script builds the Docker image and runs the container non-interactively.

## Files

- `histogram.R` — scrape, parse, clean, tabulate, and plot
- `Dockerfile` — R runtime + package dependencies
- `run.sh` — build and execute in Docker
