# Baltimore City Homicide Analysis Dashboard

**Author:** Osita  
**Course:** COSC 352

## Overview

Interactive Shiny dashboard for Baltimore Police Department crime analysis with 5+ visualizations, 6 user controls, and real-time filtering.

## Quick Start
```bash
chmod +x run_dashboard.sh
./run_dashboard.sh
```

Open browser to: **http://localhost:3838**

## Features

### 5 Dashboard Tabs
1. **Overview** - Executive summary with key metrics
2. **Trends** - Monthly patterns and clearance rates
3. **Demographics** - Victim age analysis
4. **Geographic** - District-level breakdown
5. **Data Table** - Searchable data with CSV download

### Interactive Controls
- Year range slider (2023-2025)
- Age range slider
- Method checkboxes (Shooting, Stabbing, etc.)
- Case status filter
- CCTV filter

### Summary Statistics
- Total homicides
- Clearance rate (%)
- Average victim age
- CCTV coverage (%)

## Requirements

- Docker installed and running

## Stop Dashboard
```bash
docker stop baltimore-dashboard-run
```

## Technology

- R + Shiny + shinydashboard
- plotly for interactive charts
- DT for data tables
- Docker for deployment

## Author
