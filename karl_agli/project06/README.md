# Project 6 - Data Processing Capstone Part 2
## BPD Homicide Analysis Dashboard

**Course:** COSC 352 - Spring 2026  
**Student:** Karl Agli

---

## Overview

This project extends the Part 1 homicide data pipeline into a fully interactive **Shiny dashboard** built for the Baltimore City Police Department. Analysts, detectives, and commanders can filter and explore homicide data from 2024 and 2025 scraped live from [chamspage.blogspot.com](https://chamspage.blogspot.com).

---

## Features

- **Year Filter:** Select 2024, 2025, or all years combined.
- **Method Filter:** Filter by Shooting, Stabbing, or Other/Unknown.
- **Age Slider:** Narrow results to a specific victim age range.
- **Summary Stats Panel:** Shows total homicides, case clearance rate, average victim age, and most common method — all dynamically updated with filters.
- **Monthly Homicides Chart:** Interactive bar chart comparing homicides by month across years.
- **Method Distribution Chart:** Pie chart showing breakdown by killing method.
- **Raw Data Table:** Full searchable/sortable data table.

---

## Files

| File | Description |
|------|-------------|
| `app.R` | Shiny application (single-file, includes data pipeline from Part 1) |
| `Dockerfile` | Builds R + Shiny environment with all required packages |
| `run_dashboard.sh` | Single-command entry point: builds image and launches dashboard |
| `README.md` | This file |

---

## How to Run (Part 2)

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/) installed and running.

### Steps

```bash
# Clone the repo (if not done already)
git clone https://github.com/karlagli791/COSC_352_SPRING_2026.git
cd COSC_352_SPRING_2026/karl_agli/project06

# Make the script executable and run
chmod +x run_dashboard.sh
./run_dashboard.sh
```

Then open your browser to: **http://localhost:3838**

A grader can run `./run_dashboard.sh`, wait ~30 seconds for the image to build, and immediately interact with the dashboard.

---

## Data Source

Data is scraped live from:
- [2025 Baltimore City Homicide List](https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html)
- [2024 Baltimore City Homicide List](https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html)

The scraping and cleaning pipeline is inherited and improved from **Project 5 (Part 1)** using `rvest`, `dplyr`, `stringr`, and `lubridate`.

---

## Dashboard Screenshots

> *Screenshots would be added here after running the dashboard locally.*

---

## Packages Used

- `shiny` - Web application framework
- `shinydashboard` - Dashboard layout components
- `rvest` - Web scraping
- `dplyr` - Data manipulation
- `stringr` - String operations
- `ggplot2` - Visualizations
- `lubridate` - Date parsing
- `plotly` - Interactive charts
- `DT` - Interactive data tables
