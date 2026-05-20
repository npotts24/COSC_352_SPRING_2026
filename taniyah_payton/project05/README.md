# Baltimore City Homicide Histogram

## What this project does

This project scrapes **five years of Baltimore City homicide records** (2021–2025) from [chamspage.blogspot.com](https://chamspage.blogspot.com/), parses the HTML tables, cleans the data, and produces:

1. **A ggplot2 histogram** (`/output/histogram.png`) showing the age distribution of homicide victims, stacked by year.
2. **A tabular histogram** printed to stdout — suitable for grading in a non-interactive Docker run.
3. Bonus console tables for **method breakdown** (shooting/stabbing/etc.) and **annual victim counts**.

---

## Chosen Statistic: Victim Age Distribution

### Why it's interesting

Age is the most reliably populated field across all five years and directly reveals *who* is being killed in Baltimore. The data consistently shows that the overwhelming majority of victims are between **18 and 34 years old**, with a sharp peak in the **20–29** bin. This concentration among young adults — many still in their early 20s — is a defining (and tragic) feature of urban gun violence. Visualising five years at once shows whether this demographic skew has remained stable or shifted over time.

Alternatives like "homicides by month" are interesting but susceptible to partial-year noise (2025 is still in progress). Age avoids this and speaks directly to the human cost.

---

## Data Source

| Year | URL |
|------|-----|
| 2025 | https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html |
| 2024 | https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html |
| 2023 | https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html |
| 2022 | https://chamspage.blogspot.com/2022/01/2022-baltimore-city-homicide-list.html |
| 2021 | https://chamspage.blogspot.com/2021/01/2021-baltimore-city-homicide-list.html |

Each page contains an HTML table with fields including: No, Name, Age, Date, Address, Cause/Method, Camera nearby, Case closed.

---

## Cleaning Decisions

- **Header rows** are detected by checking if the first cell contains "No", "#", or "Num" (case-insensitive) and dropped.
- **Ages** are extracted as the first integer in the age cell; rows where age is missing, zero, or implausibly large (>110) are excluded.
- **Dates** are parsed with `lubridate::parse_date_time()` supporting `m/d/Y`, `m/d/y`, and various month-name formats.
- **Cause of death** is collapsed into six categories: Shooting, Stabbing, Blunt/Assault, Asphyxiation, Vehicle, Other.
- **Camera** and **Closed** fields are normalised to `TRUE/FALSE` by checking whether the cell starts with "Y" (case-insensitive).
- Rows with all-blank text (common in multi-cell merged headers) are dropped.
- If a year's page is unreachable, the script logs the failure and continues with the remaining years rather than crashing.

---

## Running

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running

### Steps

```bash
git clone <your-repo-url>
cd <repo-dir>
chmod +x run.sh
./run.sh
```

The script will:
1. Build the Docker image (installs R + packages — ~5 min on first run)
2. Run the container, which scrapes the blog and prints the tabular histogram
3. Save `histogram.png` to `./output/`

---

## Files

| File | Purpose |
|------|---------|
| `histogram.R` | Main R script: scrape → clean → visualise → print |
| `Dockerfile` | Reproducible R 4.3.3 environment with all CRAN dependencies |
| `run.sh` | One-command build + run entry point |
| `README.md` | This file |
