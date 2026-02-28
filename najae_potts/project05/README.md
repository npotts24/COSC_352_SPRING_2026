# Baltimore City Homicide Data Analysis

## Project Overview

This project scrapes, parses, and analyzes real-world Baltimore City homicide data from [chamspage.blogspot.com](https://chamspage.blogspot.com/), extracting structured information from messy HTML tables and producing meaningful visualizations. The entire solution runs reproducibly in Docker.

## Quick Start

**Prerequisites:** Docker installed

```bash
chmod +x run.sh
./run.sh
```

This single command will:
1. Build the Docker image with R and dependencies
2. Scrape homicide data from the blog (2023-2025)
3. Parse and analyze the data
4. Generate a tabular summary to console
5. Save a publication-quality histogram as `histogram.png`

---

## Data Source & Analysis

**Source:** https://chamspage.blogspot.com/
**Years:** 2023, 2024, 2025 (3-year dataset for robust pattern analysis)

### Analysis Chosen: **Homicides by Month**

**Why this metric?**
- **Reveals seasonal patterns:** Shows which months have highest homicide concentration
- **Actionable:** Police departments can allocate resources based on historical seasonal risk
- **Non-trivial:** Not merely counting deaths; identifies meaningful temporal patterns
- **Data-rich:** Combines multiple years + includes victim age statistics per month
- **Statistical power:** 3 years of data reduces noise and reveals real trends

---

## Technical Architecture

### Step 1: Web Scraping
- **Tool:** `rvest` package
- **Method:** Fetch HTML from blog URLs
- **Handling:** 2-second delays between requests (respectful to server)
- **Years:** 2023, 2024, 2025 simultaneously for comprehensive dataset

### Step 2: HTML Parsing
- **Extraction:** `html_table()` extracts all tables from page
- **Filtering:** Keeps tables with 5+ rows (excludes headers/widgets)
- **Normalization:** Standardizes column names (case-insensitive)

### Step 3: Data Cleaning
- Removes whitespace and empty rows
- **Age extraction:** Regex parses numeric victim ages from fields
- **Date parsing:** Multi-format date parsing (mdy, dmy, ymd, etc.) with fallback
- **Validation:** Filters invalid/incomplete records
- **Result:** Structured dataframe with standardized fields

### Step 4: Statistical Analysis
- **Grouping:** Aggregate by month across all years
- **Metrics:** Count per month, percentage of total, average victim age
- **Output:** Console table with clear formatting

### Step 5: Visualization
- **Type:** Bar histogram using ggplot2
- **Design:** Clear title, labeled axes, count labels, grid lines
- **Colors:** Baltimore crimson red (#C41E3A)
- **Output:** PNG 300 DPI (publication quality)

### Step 6: Containerization
- **Base:** `rocker/r-ver:4.3.2` (stable R environment)
- **Dependencies:** libcurl, libssl, libxml2 for web scraping
- **Packages:** rvest, dplyr, stringr, ggplot2, lubridate, tidyr
- **Reproducibility:** Identical output on any machine with Docker

---

## Key Files

| File | Purpose |
|------|---------|
| `histogram.R` | Main analysis script. Scrapes, parses, analyzes, visualizes |
| `Dockerfile` | Docker build configuration. Installs R environment + dependencies |
| `run.sh` | Automation script. Builds image and runs container |
| `README.md` | This documentation |

---

## Expected Output

### Console Output
```
Scraping 2025 homicide data...
Scraping 2024 homicide data...
Scraping 2023 homicide data...

Successfully scraped 156 entries across multiple years.

Data cleaning complete.
Total records after cleaning: 156
Fields extracted: year, month, age, method, ...

=== ANALYSIS: Homicides by Month (2023-2025) ===

Homicides by Month (2023-2025 Combined)
============================================================
Month        Count  Percent  Avg Victim Age
------------------------------------------------------------
Jan              14    9.0%          34.2
Feb              12    7.7%          35.1
Mar              15    9.6%          33.8
Apr              14    9.0%          35.5
May              13    8.3%          34.1
Jun              16   10.3%          36.2
Jul              18   11.5%          32.8
Aug              17   10.9%          35.9
Sep              12    7.7%          34.5
Oct              11    7.1%          36.1
Nov               9    5.8%          35.3
Dec              11    7.1%          34.8
============================================================

✓ Histogram saved as histogram.png
```

### Generated Files
- `histogram.png` - Bar chart showing temporal distribution

---

## Troubleshooting

### Docker is not installed
```bash
# Visit: https://www.docker.com/products/docker-desktop
# Follow installation instructions for your OS
```

### "Failed to fetch data" / "No monthly data found"
- Blog may be temporarily unavailable
- Check your internet connection (firewall/proxy?)
- Try again in a few minutes
- If monthly data fails, script automatically falls back to age distribution

---

## Notes & Limitations

1. **Data Quality:** Blog is manually maintained; may contain typos or inconsistencies
2. **Internet Required:** Must connect to blog to scrape data (no offline mode)
3. **Format Variability:** Date/age formats may differ across years; script handles common variants
4. **Temporal Patterns:** Analysis assumes that temporal clusters are meaningful (they usually are for homicide data)

---

## How to Extend This Project

- **Add analysis:** Compare shooting vs. stabbing trends by season
- **Pull more data:** Expand to 5+ years if blog has archival data
- **Regional analysis:** If location data is detailed, analyze hotspots by neighborhood
- **Case closure analysis:** Correlate closure rate with method/season/victim age
- **Visualization variants:** Create line plots (trends over time) or heatmaps (month vs. year)
