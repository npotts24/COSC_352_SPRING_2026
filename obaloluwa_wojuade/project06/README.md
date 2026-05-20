# Project 06: Baltimore Homicide Analysis Dashboard (Shiny + Docker)

## Overview

This project delivers an interactive homicide analysis dashboard for the Baltimore City Police Department.

The app reuses and extends the Project 05 scraping and parsing pipeline to collect Baltimore homicide records from Cham's blog and present them in an operational dashboard suitable for command briefings and detective-level exploration.

Data source pages (scraped dynamically at startup, with cache fallback):

- https://chamspage.blogspot.com/2022/01/2022-baltimore-city-homicide-list.html
- https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html
- https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html
- https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html
- https://chamspage.blogspot.com/2026/01/2026-baltimore-city-homicide-list.html (if available)

## Dashboard Features

### Interactive visualizations

1. Monthly homicide trend by year (interactive line chart)
2. Method by case status (interactive stacked bar chart)
3. Top geographic areas by homicide count (interactive bar chart)

All visualizations update live based on filter selections.

### User controls

- Date range filter
- Victim age range slider
- Method multi-select
- Geographic area multi-select
- Case status checkboxes (Closed/Open/Unknown)
- CCTV proximity checkboxes (Yes/No/Unknown)
- Victim sex filter
- Victim race filter

### Summary statistics panel

The dashboard displays dynamic KPI values for the active filter set:

- Total homicides
- Clearance rate
- Average victim age
- Percentage near CCTV
- Most common method
- Year-over-year change in homicide count

## Files

- app.R: Shiny app (UI + server + scraping/cleaning pipeline)
- Dockerfile: Container image definition for Shiny server
- run_dashboard.sh: One-command build + run launcher

## Run Instructions

From this project directory:

```bash
chmod +x run_dashboard.sh
./run_dashboard.sh
```

Then open:

- http://localhost:3838

To stop the running dashboard:

```bash
docker rm -f cosc352-project06-homicide-dashboard
```

## Notes on Data Pipeline and Resilience

- The app scrapes all available yearly tables and normalizes inconsistent HTML structures.
- It caches cleaned data in a writable temporary file during runtime.
- On startup, it prefers fresh cache for speed, attempts live scraping when needed, and falls back to cache if scraping fails.
- Filter combinations that return zero records are handled gracefully (no crashes; informative messages shown in plots/table).

## Screenshots

### Dashboard overview (filters, KPIs, and trends)

![Dashboard overview](Screenshot%202026-03-12%20at%2010.09.12%E2%80%AFPM.png)

### Sidebar controls and filter options

![Sidebar filters](Screenshot%202026-03-12%20at%2010.12.06%E2%80%AFPM.png)
