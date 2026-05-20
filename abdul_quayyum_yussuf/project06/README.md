# Baltimore City Police Department Homicide Analysis Dashboard

## Overview

This project provides a comprehensive analysis of Baltimore City homicides through an interactive web dashboard. The project reuses the data pipeline from Project 5, scraping homicide data from the Chamspage blog for 2025 and 2026, and processes it for police department briefings and investigative analysis.

### Interactive Shiny Dashboard
Dynamic web application providing real-time filtering, multiple interactive visualizations, and summary statistics for operational decision-making.

## Quick Start

```bash
./run_dashboard.sh          # builds Docker image & starts container
# open http://localhost:3838
```

Requires only Docker. No other dependencies needed.

## Features

### Interactive Filters
- **Year Range**: Select specific years (2025-2026) to analyze
- **Month**: Multi-select dropdown for filtering by months
- **Victim Age Range**: Slider to filter by minimum and maximum victim age
- **Include Unknown Ages**: Checkbox to include/exclude records with missing age data
- **Case Status**: Filter by case closure status (All/Open/Closed)
- **Camera Proximity**: Filter by CCTV camera presence (All/No cameras/1+ cameras)
- **Address Search**: Free-text search within incident addresses

### Visualizations
All charts update dynamically based on applied filters:

1. **Monthly Homicides by Year**: Bar chart showing monthly homicide trends by year
2. **Case Status Breakdown**: Pie chart displaying open vs closed cases
3. **Top 15 Locations**: Bar chart showing incidents by street
4. **Yearly Comparison**: Bar chart comparing total homicides by year
5. **Cumulative Homicides — Year-over-Year Pace**: Line chart showing running homicide counts by day-of-year
6. **Camera Coverage Distribution**: Bar chart showing incidents by camera proximity
7. **Clearance Rate by Year**: Bar chart with rates and sample sizes
8. **Age Distribution**: Histogram with 5-year bins and interactive hover
9. **Age Groups by Year**: Side-by-side comparison of age categories across years
10. **Filtered Case Records**: Filterable, sortable table of all incident data with per-column filters

### Summary Statistics Panel
- Total homicides in filtered period
- Case clearance rate (%)
- Median victim age
- Year-over-year change
- Youngest victim age
- Oldest victim age
- Percentage of victims under 25
- Percentage of incidents near CCTV cameras
- Year-over-year comparison
- Age demographics (youngest/oldest, % under 25)

## Dashboard Tabs (Part 2)

### 1. Command Brief
Executive summary for department leadership:
- Value boxes with key metrics (totals, rates, comparisons)
- Monthly homicide trends comparison
- Case status breakdown (pie chart)
- Top 15 incident locations
- Yearly comparison bars

### 2. Trends
Operational pattern analysis:
- Cumulative year-over-year pace comparison
- Camera coverage distribution
- Clearance rates by year

### 3. Demographics
Victim profile insights:
- Age-related value boxes
- Age distribution histogram
- Age group comparisons by year

### 4. Case Records
Complete searchable data table with:
- Per-column filtering
- Color-coded status indicators
- Click-to-sort headers
- Full incident details

## Files

| File | Purpose |
|------|---------|
| `app.R` | Shiny application with UI, server logic, and embedded data pipeline |
| `Dockerfile` | Container build (rocker/shiny + plotly, DT, ggplot2, rvest, etc.) |
| `run_dashboard.sh` | One-command build and run script |
| `shiny-server.conf` | Custom Shiny Server configuration |
| `data/homicides_cache.csv` | Cached homicide data (354+ records) |
| `README.md` | This comprehensive documentation |

## Data Pipeline

The application embeds the same robust scraping functions from Part 1:

1. **Scraping**: Pulls HTML tables from Cham's Page blog posts (2023-2025)
2. **Table Detection**: Automatically detects and normalizes inconsistent table layouts
3. **Data Cleaning**: Parses dates, extracts ages, standardizes camera and status fields
4. **Caching**: Loads from `data/homicides_cache.csv` on startup; scrapes live if cache missing
5. **Processing**: Age extraction, method classification, district parsing, geocoding for maps

**To force fresh data**: Delete `data/homicides_cache.csv` and restart the application.

## Requirements

- Docker (for containerized deployment)
- Web browser (for dashboard access)
- Internet connection (for initial data scraping if cache is missing)

## Usage Notes

- All filters work reactively - charts update immediately when controls change
- Use the "Reset All Filters" button to restore default settings
- Charts support interactive features (hover tooltips, zoom, pan)
- Data table allows column-specific filtering and sorting
- Dashboard runs on `http://localhost:3838` after starting

## Data Sources

- Primary: Cham's Page Baltimore homicide blog posts
- Years covered: 2023-2025
- Total records: 354+ homicides
- Fields: Date, victim info, location, method, camera proximity, case status

### Files in Part 2 (project06)
- `app.R` – Single-file Shiny application with full dashboard functionality.
- `Dockerfile` – Docker configuration for running the Shiny app in a container.
- `run_dashboard.sh` – Shell script to build and run the dashboard container.
- `README.md` – This documentation.

### How to Run
1. Ensure Docker is installed on your system.
2. Navigate to the project06 directory.
3. Run the dashboard:
   ```bash
   ./run_dashboard.sh
   ```
4. Open your browser and go to `http://localhost:3838` to access the dashboard.

The script will automatically build the Docker image and start the container. The dashboard will scrape data on first run and cache it for subsequent uses.

### Screenshots
*(Placeholder for dashboard screenshots)*

- **Dashboard Overview**: Main interface with filters and summary statistics.
- **Trends Chart**: Example of the homicides over time visualization.
- **Incident Map**: Sample map view with markers.
- **Data Table**: Filtered data table view.

### Technical Details
- Built with Shiny and shinydashboard for the web interface.
- Uses Plotly for interactive charts and Leaflet for mapping.
- Geocoding performed using the tidygeocoder package.
- All dependencies are CRAN packages for reproducibility.
- Containerized with Docker for easy deployment.

### Edge Cases Handling
- Displays friendly messages when no data matches filters.
- Gracefully handles missing or NA values in all columns.
- Fallback to cached data if scraping fails.
