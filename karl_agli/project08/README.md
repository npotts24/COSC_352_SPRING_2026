# Project 08 — Part 2: Baltimore City Open Data Analysis

## Overview

This project extends the `csvprof` tool from Part 1 (project07) to analyze two open datasets from [Baltimore City Open Data](https://data.baltimorecity.gov/) and answer a research question that requires correlating information across both files.

## Repository Structure

```
project08/
  data/
    crime_data.csv          # Part 1 Crime Data (neighborhood-level aggregated counts)
    requests_311.csv        # 311 Service Requests 2024 (neighborhood-level aggregated counts)
  reports/
    crime_data_profile.txt  # csvprof output for crime_data.csv
    requests_311_profile.txt # csvprof output for requests_311.csv
  src/
    main.rs                 # Part 2 analysis binary
  Cargo.toml
  README.md
```

---

## Dataset 1 — Part 1 Crime Data (Legacy SRS)

- **Name:** Part 1 Crime Data (Legacy SRS)
- **Source URL:** https://data.baltimorecity.gov/datasets/baltimore::part-1-crime-data-legacy-srs/about
- **Description:** Records major (Part 1) crimes — including homicide, robbery, aggravated assault, burglary, larceny, and auto theft — reported to the Baltimore Police Department. The data used here is aggregated at the neighborhood level, showing total historical crime counts per neighborhood.
- **Key Columns Used:**
  - `Neighborhood` — Baltimore neighborhood name (join key)
  - `crime_count` — Total number of Part 1 crimes recorded in that neighborhood

---

## Dataset 2 — 311 Customer Service Requests 2024

- **Name:** 311 Customer Service Requests 2024
- **Source URL:** https://data.baltimorecity.gov/datasets/baltimore::311-customer-service-requests-2024/about
- **Description:** Represents all non-emergency 311 service calls and complaints filed by Baltimore City residents during the 2024 calendar year. Includes service request types (e.g., potholes, code violations, illegal dumping) and status. The data used here is aggregated at the neighborhood level.
- **Key Columns Used:**
  - `Neighborhood` — Baltimore neighborhood name (join key)
  - `request_count` — Total number of 311 service requests submitted from that neighborhood in 2024

---

## Research Question

Do Baltimore neighborhoods with higher Part 1 crime counts also generate significantly more 311 non-emergency service requests, and if so, how strong is this correlation at the neighborhood level?

---

## How to Run

```bash
cd project08
cargo run -- 
```

Or run the binary directly:

```bash
cargo build --release
./target/release/analyze
```

The program reads `data/crime_data.csv` and `data/requests_311.csv`, joins them on `Neighborhood`, and outputs the Pearson correlation coefficient plus tier-based averages.

---

## Part 1 Code Reuse

This project imports the `csvprof` library from project07 via a Cargo path dependency:

```toml
csvprof = { path = "../project07" }
```

The following components from Part 1 are directly used in `src/main.rs`:

| Part 1 Component | Usage in Part 2 |
|---|---|
| `read_csv_columns()` | Streams both CSV files into column vectors |
| `DefaultColumnAnalyzer` (impl of `ColumnAnalyzer` trait) | Profiles each column for type, nulls, and unique values |
| `CsvProfError` (custom error type) | Propagated via `?` operator for all I/O and CSV errors |

No CSV reading, column profiling, or error handling logic is duplicated in Part 2.

---

## Answer

After joining the two datasets on `Neighborhood`, **262 neighborhoods** were matched across both files.

The program computes a Pearson correlation coefficient between `crime_count` and `request_count` across all matched neighborhoods.

**Key findings:**

- **Pearson correlation coefficient: r ≈ 0.8341**
- **Average 311 requests in the top-third (highest-crime) neighborhoods: ~7,842**
- **Average 311 requests in the bottom-third (lowest-crime) neighborhoods: ~983**
- **Ratio: ~7.98x** more 311 requests in high-crime vs. low-crime neighborhoods

**Top 5 highest-crime neighborhoods:**

| Neighborhood | Crime Count | 311 Requests |
|---|---|---|
| DOWNTOWN | 22,854 | 16,610 |
| BELAIR-EDISON | 13,604 | 29,281 |
| FRANKFORD | 15,276 | 10,130 |
| BROOKLYN | 11,988 | 10,829 |
| CANTON | 9,491 | 11,765 |

The **strong positive Pearson correlation (r ≈ 0.83)** indicates that Baltimore neighborhoods with higher cumulative Part 1 crime totals tend to generate significantly more 311 service requests. High-crime neighborhoods average nearly 8x the 311 call volume of low-crime neighborhoods. This suggests a compounding burden in distressed neighborhoods — where elevated crime co-occurs with elevated infrastructure complaints (potholes, illegal dumping, code violations), placing disproportionate demand on city services.

---

## Limitations

1. **Temporal mismatch:** The crime dataset is historical/cumulative (all years available), while the 311 dataset covers only 2024. This means a neighborhood with high historical crime may have improved (or worsened) considerably by 2024, so the correlation reflects a structural pattern rather than a time-locked snapshot.
2. **Causation vs. correlation:** A high correlation does not imply that crime causes 311 calls or vice versa. Both may reflect underlying socioeconomic conditions (poverty, housing vacancy, disinvestment) that independently drive both metrics.
3. **Neighborhood name normalization:** The crime dataset uses uppercase neighborhood names while 311 uses mixed-case. The join normalizes both to uppercase, but minor spelling differences between datasets may cause some neighborhoods to be excluded from the matched set.
