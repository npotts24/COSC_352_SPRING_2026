# Project 5 - Data Processing Capstone #1

## Overview
This project scrapes Baltimore City homicide data from
[chamspage.blogspot.com](https://chamspage.blogspot.com) for **2023, 2024, and 2025**,
parses it into a structured R data frame, and produces multiple tabular
histograms printed to stdout.

## Statistic Chosen: Homicides by Month (Multi-Year Comparison)

### Why it is interesting
Homicide rates in Baltimore follow well-documented seasonal patterns -
summer months (May-August) historically see significantly higher counts than
winter. By comparing three consecutive years side-by-side we can see whether
2025 is following the same seasonal trend or deviating, which has direct
implications for resource allocation in the Baltimore Police Department.

## Files

| File | Purpose |
|---|---|
| `histogram.R` | Scrapes, parses, and prints four tabular histograms |
| `Dockerfile` | Builds R 4.3.3 image with all required packages |
| `run.sh` | Single entry point: builds image and runs container |
| `README.md` | This file |

## Running the Project

```bash
chmod +x run.sh
./run.sh
```

Docker must be installed. No other dependencies are needed.

## Output

Four tables are printed to stdout:

1. **Homicides by Month** (2023-2025 combined) with ASCII bar chart
2. **Year-over-Year Monthly Breakdown** - columns for each scraped year
3. **Method Breakdown** - Shooting vs Stabbing vs Other (from Notes column)
4. **Age Distribution** (2025 only) - binned into 10-year groups

## Data Cleaning Decisions

- Rows where the date could not be parsed are dropped (header-repeat rows,
  placeholder entries like "XXX").
- Ages outside 1-109 are excluded as likely data entry errors.
- Method is inferred from the Notes column via keyword matching:
  - "shoot / shot / gunshot" -> Shooting
  - "stab" -> Stabbing
  - "beat / assault" -> Assault
  - everything else -> Other/Unknown
- Only rows with a valid parsed date contribute to monthly counts.
