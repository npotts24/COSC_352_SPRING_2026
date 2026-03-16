# Baltimore Homicide Trend Analysis (2025)

## Chosen Statistic
This project analyzes the victims of homicide trends in Baltimore with labelled age groups.

## Why This Is Interesting
Rather than examining the homicide trends of criminals, this analysis identifies:

- Homicide Victims Patterns
- Victims Age groups


This provides a stronger analytical story about age groups affected through the  one-year histogram.

## Data Cleaning Decisions
- Dates were parsed using lubridate to handle inconsistent formatting.
- Missing months were filled with zero counts.
- Tables were combined programmatically due to inconsistent HTML structure.
- Failed year loads are safely handled using tryCatch.


##File Structure:
project05/
├── Dockerfile # Docker setup for R environment
├── run.sh # Script to build Docker image, run analysis, and generate histogram
├── histogram.R # R script for scraping, cleaning, and plotting
└── README.md # Project documentation



---

## How to Run

1. Open a terminal and navigate to the project folder:

```bash
cd /path/to/project05


chmod +x run.sh

./run.sh


##This Script will:

Build a Docker image with all necessary R packages.

Scrape homicide data for 2023–2025.

Clean and process the data.

Generate a histogram of victim age distribution.

Save the histogram as histogram.png.


Author - Rochak Ghimire

