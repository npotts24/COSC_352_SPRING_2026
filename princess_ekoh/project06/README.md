# Project 06 - Baltimore Homicide Shiny Dashboard

## Overview
This project builds an interactive Shiny dashboard for exploring Baltimore City homicide data scraped from Cham's blog.

## Features
- Live scraping of 2024 and 2025 homicide list pages
- Filters for:
  - Year
  - Victim age range
  - Method
  - Case status
  - CCTV nearby
- Summary statistics:
  - Total filtered homicides
  - Estimated clearance rate
  - Average victim age
  - Percentage of incidents near CCTV
- Interactive visualizations:
  - Homicides by month
  - Method breakdown
- Interactive data table

## Files
- app.R - Shiny dashboard
- Dockerfile - Docker environment
- run_dashboard.sh - builds and runs dashboard
- README.md - documentation

## Run Instructions

chmod +x run_dashboard.sh  
./run_dashboard.sh

Then open:

http://localhost:3838
