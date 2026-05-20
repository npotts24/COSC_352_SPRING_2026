# Part 2: BPD Homicide Analysis Dashboard

Interactive Shiny dashboard for Baltimore City Police Department homicide data
(2024-2025), built on the Project 5 web-scraping pipeline.

## Quick Start

```bash
./run_dashboard.sh          # builds image & starts container
# open http://localhost:3838
```

Requires only Docker. No other dependencies.

## Files

| File | Purpose |
|------|---------|
| `app.R` | Shiny application -- UI, server logic, and embedded data pipeline |
| `Dockerfile` | Container build (rocker/shiny + plotly, DT, ggplot2, rvest) |
| `run_dashboard.sh` | One-command build and run script |
| `shiny-server.conf` | Custom Shiny Server configuration |
| `data/homicides_cache.csv` | 354-row cache from the Project 5 pipeline |

## Dashboard Tabs

### 1. Command Brief

Summary for department leadership at a glance:

- **Value boxes** -- total homicides, clearance rate, median victim age,
  year-over-year change (color-coded up/down).
- **Monthly homicides by year** -- grouped bar chart comparing 2024 vs 2025
  month by month (interactive plotly -- hover, zoom, pan).
- **Case status breakdown** -- pie chart of open vs closed cases.
- **Top 15 locations** -- horizontal bar chart of the most-affected streets.
- **Yearly comparison** -- bar chart with labeled counts.

### 2. Trends

Operational patterns for analysts:

- **Cumulative pace chart** -- line chart plotting each year's running homicide
  count by day-of-year so a commander can see whether the city is ahead of or
  behind last year's pace.
- **Camera coverage** -- bar chart showing how many incidents occurred near 0, 1,
  2, or 3 cameras.
- **Clearance rate by year** -- bar chart with rate and n/N annotation.

### 3. Demographics

Victim profile analysis:

- **Value boxes** -- youngest victim, oldest victim, % under 25, % near a camera.
- **Age histogram** -- 5-year bins with interactive hover.
- **Age groups by year** -- side-by-side comparison of 0-17, 18-25, 26-35, 36-45,
  46-55, 56+ across years.

### 4. Case Records

Full searchable, sortable data table (DT) of all filtered records with:
- Per-column filters
- Color-coded status cells (green = closed, red = open)
- Click-to-sort column headers

## Sidebar Controls (7 inputs + Reset)

| Control | Type | Purpose |
|---------|------|---------|
| Year | Checkbox group | Select individual years |
| Month | Multi-select | Filter by one or more months |
| Victim age | Range slider | Set age bounds |
| Include unknown ages | Checkbox | Keep/drop records with missing age |
| Case status | Dropdown | All / Open / Closed |
| Camera proximity | Dropdown | All / No cameras / 1+ cameras |
| Address search | Text input | Free-text substring match on address |
| Reset All Filters | Button | Restore every control to defaults |

All charts and summary statistics update reactively when any filter changes.

## Data Pipeline (reuses Project 5)

The app embeds the same scraping functions from `project05/histogram.R`:

1. Scrapes HTML tables from Cham's Page blog for 2023-2025.
2. Detects column headers and normalizes inconsistent table layouts.
3. Parses dates, extracts ages, standardizes camera and status fields.
4. On startup the app loads `data/homicides_cache.csv`; if absent it scrapes
   live and writes the cache.

Delete the cache to force a fresh scrape on next launch.
