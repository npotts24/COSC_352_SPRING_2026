# Baltimore City Homicide Data Analysis

This project scrapes, analyzes, and visualizes homicide data from Baltimore City using R and Docker.

## Author
Gulam Uddin  
Morgan State University  
Computer Science

## Overview

This analysis examines homicide patterns in Baltimore City by scraping data from [Cham's Page](https://chamspage.blogspot.com/), a blog that maintains detailed records of Baltimore City homicide victims.

## Chosen Statistic: Monthly Distribution of Homicides

**What it shows:** This histogram displays the distribution of homicides across the months of the year.

**Why it's interesting:** 
- Reveals seasonal patterns in violent crime
- Can help police departments anticipate resource needs during high-crime months
- May correlate with weather patterns, school schedules, or other temporal factors
- Historical data shows violent crime often peaks in summer months

**Potential insights:**
- If homicides cluster in certain months, this suggests environmental or social factors at play
- Resource allocation: Police can deploy more officers during historically high-crime months
- Community intervention programs can be scheduled proactively before peak months

## Data Source

The primary data source is the 2025 Baltimore City Homicide List:
```
https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html
```

The script also pulls data from 2024 and 2023 for a more comprehensive analysis (you can modify the `years_to_scrape` variable in `histogram.R` to include more years).

Each record typically includes:
- Victim name and age
- Date of death
- Location/address
- Method (shooting, stabbing, etc.)
- CCTV camera presence
- Case closure status

## Data Cleaning Decisions

1. **Date Parsing**: Used `lubridate::mdy()` to parse various date formats found in the HTML tables
2. **Missing Data**: Filtered out records with NA values in the date field
3. **Age Extraction**: Extracted numeric ages using regex patterns to handle various formats
4. **Multiple Years**: Combined data from multiple years to increase sample size and reveal multi-year patterns

## Requirements

- Docker (no other dependencies needed on host machine)
- Internet connection (to scrape data from the blog)

## Usage

Simply run:
```bash
./run.sh
```

This will:
1. Build the Docker image with R and all dependencies
2. Run the analysis script
3. Display the histogram output in your terminal

## Project Structure

```
.
├── histogram.R       # Main R script for scraping and analysis
├── Dockerfile        # Docker configuration
├── run.sh           # Build and run script
└── README.md        # This file
```

## Dependencies (installed in Docker)

- `rvest`: Web scraping
- `dplyr`: Data manipulation
- `stringr`: String operations
- `lubridate`: Date/time parsing

## Output

The script produces:
1. **Tabular output**: A table showing homicide counts by month
2. **ASCII histogram**: A visual bar chart rendered in the terminal
3. **Summary statistics**: Total records scraped and processed

## Assumptions

- The blog's HTML structure remains consistent with the format as of January 2025
- Tables are structured with consistent column headers
- Dates are in MM/DD/YYYY format
- The first table on each page contains the homicide data

## Potential Improvements

- Add error handling for network failures with retry logic
- Create graphical visualizations (PNG/PDF output) using ggplot2
- Analyze additional dimensions (age groups, methods, neighborhoods)
- Perform statistical tests (chi-square for seasonality)
- Add geocoding to map homicides by location
- Compare year-over-year trends

## Troubleshooting

If the script fails:
1. Check your internet connection
2. Verify the blog URL is still active
3. Examine console output for specific error messages
4. The blog structure may have changed - inspect the HTML manually

## Academic Integrity

This project was created as coursework for Morgan State University. The code is provided as a learning resource and demonstration of R programming, web scraping, and Docker containerization skills.

## License

Educational use only - Morgan State University Coursework
