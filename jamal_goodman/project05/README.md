# Baltimore City Homicide Histogram (R + Docker)

## What this does
This project scrapes homicide victim entries from Cham's blog and produces a histogram-style summary of the data.

Data source (required by assignment):
- 2025 list: https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html

To improve comprehensiveness, this project also scrapes:
- 2024 list: https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html

## Statistic chosen (Histogram)
**Homicides by month** (counts per month), comparing **2024 vs 2025**.

Why it’s interesting:
- Month-by-month counts can reveal seasonality (e.g., summer spikes vs winter lows).
- Comparing two years helps show whether patterns are consistent year-over-year.

## Output requirements
- The script prints a tabular histogram to stdout (so it’s visible in Docker / non-interactive runs).
- The script also saves a labeled chart as `histogram.png`.

## Cleaning / assumptions
- The blog tables can be messy, with links/images embedded and occasional “XXX” rows.
- Dates are parsed using `lubridate::mdy()`.
- Rows are kept only if the date parses successfully and the year matches the target year (2024 or 2025).
- Camera presence is parsed into a numeric camera count (e.g., "1 camera" -> 1, "None" -> 0).
- Case status is parsed as TRUE if it contains "Closed".

## How to run
Make sure Docker is installed, then:

```bash
chmod +x run.sh
./run.sh