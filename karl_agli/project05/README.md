# Project 5 – Data Processing Capstone #1
## Baltimore City Homicide Data Analysis

**Course:** COSC 352 – Spring 2026  
**Student:** Karl Agli

---

## Overview

This project scrapes, parses, and visualizes real-world homicide data from the public blog
[chamspage.blogspot.com](https://chamspage.blogspot.com/), which maintains yearly lists of
Baltimore City homicide victims. The entire pipeline runs inside a Docker container so it
reproduces on any machine with Docker installed.

---

## Chosen Statistic: Homicides by Month – 2024 vs 2025 (side-by-side)

### Why this statistic is interesting

A simple year-over-year monthly comparison reveals *seasonal patterns* in homicide rates and
shows whether the widely-reported decline in Baltimore violence in 2025 holds across every
month or is driven by a few outlier months. Summer months (Jun–Aug) historically spike due
to heat and outdoor activity; comparing 2024 vs 2025 lets a viewer immediately see:

- Whether the 2025 reduction was consistent year-round or concentrated in certain months.
- Which months remain dangerous despite overall improvement.
- Whether early-year patterns (Jan–Mar) differ from warm-weather months.

This is more informative than a single total count because it shows *where* in the calendar
the change occurred.

---

## Data Source

| Year | URL |
|------|-----|
| 2025 | https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html |
| 2024 | https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html |

Each page contains an HTML table with the following fields per victim:

| Column | Description |
|--------|-------------|
| No. | Sequential homicide number (or XXX for removed entries) |
| Date Died | Date of death (MM/DD/YY format) |
| Name | Victim name (linked to police advisory) |
| Age | Victim age |
| Address Block Found | Location of incident |
| Notes | Narrative including method of death |
| Victim Has No Violent Criminal History | Boolean flag |
| Surveillance Camera At Intersection? | Camera count / None |
| Case Closed? | "Closed" if solved |

---

## Data Cleaning Decisions

1. **Removed entries marked XXX** – These rows were either later reclassified as non-homicides
   (justified shootings, suicides, old cold cases added then removed) or are administrative
   placeholders. Keeping them would inflate counts.

2. **Date parsing** – Dates are stored as `MM/DD/YY`. The `lubridate::mdy()` function handles
   this automatically. A handful of entries use `MM/YYYY` (incomplete) or have typos; these
   are dropped via `NA` filtering.

3. **Year assignment** – We trust the *parsed date year* over the `year_label` passed to
   `scrape_year()` because some victims (shot in December, died in January) appear on the
   "wrong" year's page. Only rows where `year(date) %in% c(2024, 2025)` are kept.

4. **Method classification** – The "Notes" column contains free-text narratives. We classify
   method as `Shooting`, `Stabbing`, `Assault`, or `Other / Unknown` using keyword matching
   (case-insensitive).

5. **CCTV detection** – Camera presence is detected by looking for a digit (e.g. "1 camera",
   "2 cameras") vs. the word "none" in the camera column.

---

## Files

| File | Purpose |
|------|---------|
| `histogram.R` | Main R script: scrapes data, cleans it, generates histogram PNG, prints tabular output |
| `Dockerfile` | Builds `r-base:4.3.2` image with all required CRAN packages |
| `run.sh` | Single entry point: builds image, runs container, displays output |
| `README.md` | This file |

---

## How to Run

```bash
# Clone the repo (if not already done)
git clone https://github.com/karlagli791/COSC_352_SPRING_2026.git
cd COSC_352_SPRING_2026/karl_agli/project05

# Make run.sh executable and run it
chmod +x run.sh
./run.sh
```

The script will:
1. Build the Docker image (first run takes a few minutes to install R packages).
2. Run the container, which fetches data from the blog, cleans it, and prints:
   - A summary of records scraped
   - A month-by-month comparison table (2024 vs 2025)
   - A method breakdown table (Shooting, Stabbing, etc.)
   - Victim age statistics
3. Save `homicides_by_month.png` inside the container.

**Requirements:** Docker must be installed and running. No other dependencies needed.

---

## R Packages Used

| Package | Purpose |
|---------|---------|
| `rvest` | HTML scraping |
| `dplyr` | Data manipulation |
| `stringr` | String cleaning & regex |
| `ggplot2` | Histogram / visualization |
| `lubridate` | Date parsing |
| `tidyr` | Pivoting for tabular output |

All packages are available from CRAN and installed automatically via the `Dockerfile`.

---

## Sample Output (tabular)

```
=== Baltimore City Homicides by Month: 2024 vs 2025 ===
Month      2024   2025   Change
----------------------------------
Jan           X      X        +X
Feb           X      X        +X
...
TOTAL         X      X        +X
```

*(Actual numbers printed at runtime after scraping live data.)*
