# Baltimore Homicide Dashboard (Project 06)

This Shiny app is a homicide analysis dashboard for the Baltimore City Police Department. It scrapes Baltimore homicide lists from the live blog pipeline and provides interactive trend and method visualizations with filters.

## Files
- `app.R` — Shiny dashboard app with live data pipeline.
- `Dockerfile` — Builds R/Shiny container and installs dependencies.
- `run_dashboard.sh` — Builds image and runs container on `http://localhost:3838`.
- `data/baltimore_homicides.csv` — cached homicide data created at runtime.

## Features
- **Interactive visualizations**: monthly trend chart, homicide method distribution, method-month heatmap.
- **Filter controls**: year range, age slider, method selection, case status, camera coverage.
- **Summary metrics**: filtered homicide count, clearance rate, average victim age, camera coverage percentage.
- **Live data refresh**: refresh button re-scrapes data and updates filters.
- **Data table**: filtered incidents table with details.

## Run
From `iyinoluwa_ayodele/project06`:

```bash
chmod +x run_dashboard.sh
./run_dashboard.sh
```

Open: `http://localhost:3838`

## Screenshots

![Baltimore Homicide Dashboard](screenshot.png)

## Notes
- The app uses the same scraping source as Part 1 (`chamspage.blogspot.com/YYYY/01/YYYY-baltimore-city-homicide-list.html`).
- If scraping fails, it falls back to existing cached data.
