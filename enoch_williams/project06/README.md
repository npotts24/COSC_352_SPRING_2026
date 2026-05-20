# Baltimore City Homicide Analysis Dashboard - COSC 352 Project 06

## Overview

This project builds an interactive Shiny dashboard for analyzing Baltimore City homicide trends. The dashboard allows detectives, commanders, and analysts to explore homicide patterns through dynamic visualizations and filters, helping identify trends, allocate resources effectively, and track clearance rates.

## Features

### Interactive Visualizations
- **Homicides Over Time**: Line chart showing temporal trends
- **Monthly Trends**: Bar chart of homicides by month
- **Age Distribution**: Histogram of victim ages with filtering
- **Method Distribution**: Pie chart and stacked bars for homicide methods
- **Clearance Rate Trends**: Tracking case resolution over time

### User Controls
- **Year Selection**: Multi-select dropdown for years (2023-2025)
- **Age Range Slider**: Filter victims by age range
- **Method Filter**: Checkboxes for homicide methods (shooting, stabbing, blunt force, other)
- **Date Range Picker**: Filter by specific date ranges

### Summary Statistics Panel
- Total homicides in filtered dataset
- Case clearance rate percentage
- Average victim age
- Percentage of incidents with CCTV coverage

### Data Table
- Interactive table with all homicide records
- Sortable and filterable columns
- Displays year, date, age, method, location, CCTV presence, and clearance status

## Screenshots

### Dashboard Overview
![Dashboard Overview](Screenshot%202026-03-24%20144218.png)

### Data Table View
![Data Table View](Screenshot%202026-03-24%20150001.png)

## Data Source

The dashboard scrapes live data from [chamspage.blogspot.com](https://chamspage.blogspot.com/), which maintains comprehensive Baltimore City homicide records including:
- Victim demographics (age, etc.)
- Incident details (date, location, method)
- Investigation status (cleared/uncleared)
- Surveillance coverage (CCTV presence)

## Project Files

### 1. `app.R`
The main Shiny application containing:
- Data scraping and cleaning functions
- Interactive UI with dashboard layout
- Reactive server logic for filtering and plotting
- Multiple visualization tabs

### 2. `Dockerfile`
Containerizes the Shiny application with:
- Base image: `rocker/r-base:4.3.2` (stable R environment)
- System dependencies for web scraping and graphics
- R packages: shiny, shinydashboard, plotly, DT, dplyr, ggplot2, lubridate, rvest, stringr, tidyr
- Exposes port 3838 for web access

### 3. `run_dashboard.sh`
Bash script that:
- Builds the Docker image
- Runs the container with port mapping
- Provides user instructions for accessing the dashboard

### 4. `README.md`
This documentation file.

## Usage

### Quick Start

```bash
./run_dashboard.sh
```

This single command will:
1. Build the Docker image (first run takes 3-5 minutes)
2. Start the Shiny server
3. Display the dashboard URL

### Accessing the Dashboard

Once running, open your web browser and navigate to:
**http://localhost:3838**

The dashboard will load with the latest homicide data scraped from the source.

### Running on a Clean Machine

```bash
git clone <repository>
cd enoch_williams/project06
chmod +x run_dashboard.sh
./run_dashboard.sh
```

**Requirements**: Only Docker must be installed. No local R installation needed.

## Dashboard Layout

### Overview Tab
- Key metrics value boxes
- Homicides over time line chart

### Trends Tab
- Monthly homicide patterns
- Year-over-year comparisons
- Clearance rate trends

### Demographics Tab
- Victim age distribution histogram
- Age trends by year and method

### Methods Tab
- Homicide method distribution
- Method trends over time
- Clearance rates by method

### Data Tab
- Complete interactive data table

## Technical Implementation

### Data Pipeline
- Scrapes HTML tables from blog posts using `rvest`
- Cleans and standardizes column names
- Parses dates, ages, and categorical variables
- Handles missing data gracefully

### Shiny Architecture
- Reactive data filtering based on user inputs
- Plotly for interactive visualizations
- DT for data table functionality
- Shinydashboard for professional layout

### Containerization
- Fully self-contained Docker environment
- Automatic dependency installation
- Port 3838 exposed for web access

## Screenshots

*[Screenshots would be included here showing the dashboard interface]*

## Data Privacy and Ethics

This dashboard uses publicly available homicide data from news/blog sources. All analysis is performed locally within the Docker container. No personal identifiable information beyond what's already public is collected or stored.

## Future Enhancements

Potential improvements could include:
- Geographic mapping with location data
- More advanced statistical analysis
- Predictive modeling features
- Integration with official police data sources
- Real-time data updates

## Dependencies

### R Packages (CRAN)
- shiny, shinydashboard, plotly, DT
- dplyr, ggplot2, lubridate, tidyr
- rvest, stringr

### System Libraries
- libxml2-dev, libcurl4-openssl-dev, libssl-dev
- libfontconfig1-dev, libfreetype6-dev
- libpng-dev, libtiff5-dev, libjpeg-dev