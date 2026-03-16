Overview
This project delivers a fully interactive homicide analysis dashboard built for the Baltimore City Police Department. Designed for use by detectives, commanders, and crime analysts, the dashboard enables real-time exploration of Baltimore's 2025 homicide data — including victim demographics, cause of death, case clearance rates, geographic distribution, and CCTV camera coverage.
The application scrapes live data directly from the Cham's Page Baltimore Homicide Blog, parses and cleans it automatically, and presents it through an interactive Shiny interface containerized with Docker.

Dashboard Features
📊 Overview Tab

Monthly Homicide Bar Chart — color-coded by intensity, shows seasonal patterns at a glance
Cause of Death Donut Chart — proportion of shootings, stabbings, blunt force, and other methods
Case Status Breakdown — open vs. closed (arrest) vs. closed (no arrest)
Victim Age Distribution Histogram — identifies the most at-risk age groups
6 Live Summary Stat Boxes that update with every filter change:

Total homicides in filtered period
Case clearance rate (%)
Average victim age
Most common cause of death
% of incidents near CCTV cameras
Total open / unsolved cases



🗺️ Crime Map Tab

Interactive Plotly Map of all homicide incidents plotted across Baltimore City
Color-coded markers by cause of death
Hover over any marker to see victim name, date, cause, status, and age
Updates dynamically with all sidebar filters

📈 Trends Tab

Cumulative Homicide Line Chart — tracks the pace of homicides across the year
Clearance Rate by Month — color-coded bar chart (red = low, green = high clearance)
CCTV Coverage Impact — stacked bar comparing incidents near vs. not near surveillance cameras, broken down by cause

📋 Case Records Tab

Full searchable, sortable data table of all filtered records
Columns: Case No., Date, Name, Age, Address, Cause, Status, CCTV, Notes
Export to CSV or Excel with one click


Filters (Sidebar)
All filters apply instantly across every tab and visualization.
FilterTypeDescriptionYear RangeSliderFilter by year (2025+)Victim Age RangeSliderFilter by victim age (0–100)Cause of DeathCheckboxesShooting, Stabbing, Blunt Force, AsphyxiationCase StatusDropdownAll / Open / Closed (Arrest) / Closed (No Arrest)Reset All FiltersButtonRestores all filters to default

Data Source & Pipeline
Data is scraped from the Cham's Page Baltimore City Homicide Blog:
https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html
The scraper.R pipeline:

Fetches the live blog page using httr
Parses the HTML homicide table using rvest
Extracts: case number, date, name, age, address, notes
Derives cause of death and case status from the notes text
Derives CCTV proximity from notes mentioning "camera"
Saves a cached CSV to data/homicides.csv
Falls back to cache if the live site is unavailable
Falls back to demo data if no cache exists — the app never crashes


How to Run
Prerequisites

Docker Desktop installed and running
Terminal / command line access
No R installation required — everything runs inside Docker

One-Command Launch
bashgit clone <your-repo-url>
cd project-06-yourname
./run_dashboard.sh
Then open your browser and navigate to:
http://localhost:3838/bpd/
What run_dashboard.sh Does

Stops and removes any existing container
Builds the Docker image from the Dockerfile
Starts the container with port 3838 mapped
Waits 30 seconds for Shiny Server to initialize
Prints the URL to open in your browser

Stopping the Dashboard
bashdocker stop bpd-dashboard
Restarting Later
bash./run_dashboard.sh

Project Structure
project-06-yourname/
├── app.R                  # Shiny UI + Server logic
├── scraper.R              # Data pipeline (scraping, parsing, cleaning)
├── Dockerfile             # Docker build instructions
├── run_dashboard.sh       # One-command launcher script
├── data/
│   └── homicides.csv      # Cached scraped data (auto-generated)
└── README.md              # This file

Technical Stack
ComponentTechnologyDashboard FrameworkR Shiny + shinydashboardInteractive ChartsPlotly for RInteractive MapPlotly scattermapboxData TableDT (DataTables)Web Scrapinghttr + rvestData Wranglingdplyr + stringrContainerizationDocker (rocker/shiny:4.3.1)

Author:
Sandeep Shah
