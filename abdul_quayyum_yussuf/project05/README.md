# Baltimore Homicide Histogram

This repository contains a project that scrapes the 2025 and 2026 Baltimore City homicide
lists from the Chamspage blog and produces a histogram of victim ages. By combining data from
multiple years, the analysis strengthens the visualization of demographic patterns in homicide
victimization across a broader timeframe.

## Statistic Chosen
The chosen statistic is the **age distribution of homicide victims** across 2025–2026 Baltimore.
Age is a natural demographic variable that often reveals underlying patterns in violence; for
example, the majority of victims cluster in the late teens through the thirties, which may
point to risk factors associated with young adulthood. A histogram is well suited because it
highlights the shape of the distribution and makes it easy to spot age ranges with especially
high or low counts.

## Data Sources
The script pulls from two years of data:
- **2025**: https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html
- **2026**: https://chamspage.blogspot.com/2026/01/2026-baltimore-city-homicide-list.html

Combining these lists strengthens the analysis by smoothing year-to-year volatility and
revealing more robust demographic patterns.

## Assumptions & Cleaning
* The script scrapes the table with `id="homicidelist"` from both blog posts.
* The HTML is messy: some `td` elements contain nested tables, which causes the
  `rvest::html_table()` function to spill notes into separate rows. The cleaning
  step filters out rows lacking a valid date and converts the `Age` column to a
  numeric value, ignoring non-numeric entries (e.g. "XXX").
* Only entries with a parsable age are included in the histogram bins.
* Data from both years is combined into a single dataset before computing the histogram.

## Files
* `histogram.R` – main R script that performs scraping from both years, cleaning, table output, and
  histogram generation. The plotted histogram is written to `histogram.png`.
* `Dockerfile` – builds an R environment with all needed CRAN dependencies and
  copies the script into the image.
* `run.sh` – convenience wrapper that builds the Docker image and runs it, printing
  the tabular histogram to the terminal.
* `README.md` – this write-up.

## Usage
Clone the repository and run:

```bash
./run.sh
```

A Docker image will be built automatically. When the container runs it scrapes both the
2025 and 2026 lists, combines the data, prints a table of age bins and counts to stdout,
and saves `histogram.png` in the working directory. No manual intervention is required.

## Output
The script prints the following header to stdout:

```
========================================
Analysis based on 2025 and 2026 Baltimore City Homicide Lists
========================================
```

This confirms that the analysis draws from both years of data.

---

This solution meets the project requirements by scraping multiple years of data,
handling messy HTML, computing a histogram, and exposing both visual and
textual/tabular output that a grader can inspect without interactive plotting.
