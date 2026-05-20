# Baltimore City Homicides (2025) — Web Scraping & Visualization in R (Dockerized)

## Overview

This project scrapes real-world homicide data from Cham’s blog:

**2025 Baltimore City Homicide List**  
https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html  

The script extracts structured information from a messy HTML table, cleans the data, and generates two meaningful visualizations:

1. **Victim Age Distribution (5-year bins)**
2. **Method Breakdown (Shooting vs Stabbing vs Other)**

The entire project runs reproducibly inside Docker. A grader can clone the repository and run:

```bash
./run.sh