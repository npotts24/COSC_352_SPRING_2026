# Baltimore City Homicide Data Analysis - COSC 352 Project 05

## Overview

This project scrapes, parses, and visualizes Baltimore City homicide data from the blog at [chamspage.blogspot.com](https://chamspage.blogspot.com/). The analysis is fully containerized with Docker to ensure reproducibility across different machines.

## Chosen Statistic: Victim Age Distribution

### Why This Statistic Is Interesting

The **distribution of victim ages** tells an important story about homicide patterns in Baltimore City:

1. **Demographic Insight**: It reveals which age groups are most vulnerable to homicide violence
2. **Policy Implications**: Understanding age distribution helps inform prevention and intervention strategies
3. **Patterns Over Time**: Comparing age distributions across multiple years (2023-2025) shows whether violence is shifting toward particular age groups
4. **Social Context**: The ages provide context about the victims and the nature of the violence (e.g., concentration in young adults vs. elderly)

### Key Findings Expected

- Homicides typically cluster in the 15-40 age range in major urban areas
- Understanding these clusters helps guide community intervention programs
- Year-over-year trends reveal shifts in violence patterns

## Data Source

- **Primary URL**: [2025 Baltimore City Homicide List](https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html)
- **Additional Years**: The script also scrapes 2024 and 2023 data for trend analysis
- **Fields Extracted**: Victim name, age, date of incident, address, method of homicide, CCTV presence, case status

## Project Files

### 1. `histogram.R`
The main R script that:
- Scrapes homicide data from the blog using `rvest` package
- Parses HTML tables into structured R data frames
- Cleans and validates the data (especially age values)
- Generates a histogram visualization using `ggplot2`
- Prints tabular histogram data to stdout
- Produces a PNG visualization of the age distribution

### 2. `Dockerfile`
Containerizes the R environment with:
- Base image: `r-base:4.3.2`
- System dependencies: libxml2, libcurl, libssl (for web scraping)
- R packages: rvest, dplyr, stringr, ggplot2, lubridate, tidyr
- Automatic execution of the analysis script

### 3. `run.sh`
Bash script that:
- Checks for Docker installation
- Builds the Docker image
- Runs the container
- Outputs results to the terminal
- Saves the histogram PNG file to the project directory

### 4. `README.md`
This documentation file.

## Usage

### Quick Start

```bash
./run.sh
```

This single command will:
1. Build the Docker image (on first run, takes 2-3 minutes)
2. Run the analysis container
3. Print the histogram data and statistics to the console
4. Save `histogram.png` in the project directory

### Running on a Clean Machine

```bash
git clone <repository>
cd enoch_williams/project05
chmod +x run.sh
./run.sh
```

**Requirements**: Only Docker must be installed. No local R installation needed.

## Data Cleaning Decisions

1. **Age Validation**: 
   - Removed non-numeric age values
   - Filtered out impossible ages (< 0 or > 120 years)
   - Kept only records with valid age data for the main analysis

2. **Data Combining**:
   - Combined data from 2023, 2024, and 2025 to increase sample size
   - Added year column to track temporal patterns
   - Handled missing/malformed HTML gracefully with error handling

3. **Binning**:
   - Used 10-year age bins (0-10, 10-20, 20-30, etc.) for clarity
   - Provides both absolute counts and percentages

4. **HTML Parsing**:
   - Blog layout may change; script searches for tables with adequate rows/columns
   - Tries multiple table indices to find the main data table
   - Includes error handling for network issues and unexpected structure

## Output

The script produces two outputs:

### 1. Console Output (Tabular Histogram)
```
VICTIM AGE DISTRIBUTION (HISTOGRAM DATA):
============================================
  age_group count percentage
1      0-10      2        0.3
2     10-20     45        6.2
3     20-30    156       21.5
4     30-40    185       25.4
...
```

Also includes:
- Overall statistics (mean, median, std dev, min, max age)
- Record counts per year
- Data quality metrics

### 2. Visual Output
- **histogram.png**: A publication-quality visualization showing the age distribution with proper labels and annotations

## Technical Stack

- **Language**: R 4.3.2
- **Web Scraping**: rvest (using CSS/XPath selectors)
- **Data Wrangling**: dplyr, stringr, tidyr
- **Visualization**: ggplot2
- **Date Handling**: lubridate
- **Containerization**: Docker
- **Orchestration**: Bash shell script

## Assumptions & Limitations

1. **Blog Structure Stability**: The script assumes the blog maintains a similar HTML structure. If the blog is redesigned, the CSS selectors may need updating.

2. **Data Quality**: The original data may contain:
   - Missing age values (handled by filtering)
   - Inconsistent formatting (cleaned with regex)
   - Possible data entry errors (validated against reasonable ranges)

3. **Time Zone**: All dates are assumed to be in Eastern Time (Baltimore's time zone)

4. **Case Closure Dates**: If scraped, these represent the investigation stage at the time of blog posting, not final case outcomes

5. **Incomplete 2025 Data**: Jan 2026 data may be incomplete depending on when the blog was last updated

## Performance Notes

- First Docker build: ~2-3 minutes (installs all dependencies)
- Subsequent runs: ~30-60 seconds (uses cached Docker layers)
- Web scraping: ~10-15 seconds per year of data
- Data processing & visualization: <5 seconds

## Troubleshooting

### "docker: command not found"
Install Docker from [docker.com](https://www.docker.com/products/docker-desktop/)

### "Permission denied" on run.sh
```bash
chmod +x run.sh
```

### Script hangs during web scraping
The blog may be slow or temporarily unavailable. Check internet connection and try again.

### No output from histogram.R
Check Docker logs:
```bash
docker logs <container_id>
```

## Future Enhancements

- Multi-variable analysis (age vs. method, age vs. closure rates)
- Interactive Shiny dashboard
- Statistical hypothesis testing on trends
- Quarterly trend analysis
- Geographic mapping of homicide locations
- Time-series analysis of homicide frequency

## References

- Data Source: [Cham's Page - Baltimore Homicide Lists](https://chamspage.blogspot.com/)
- R Documentation: [rvest package](https://rvest.tidyverse.org/)
- Docker: [R Base Images](https://hub.docker.com/_/r-base)

---

**Author**: Enoch Williams  
**Course**: COSC 352 - Spring 2026  
**Date**: March 2026
