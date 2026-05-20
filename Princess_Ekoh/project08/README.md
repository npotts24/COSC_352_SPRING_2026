# Project 08 — Baltimore City Open Data Analysis

## Overview

This project analyzes two datasets from the Baltimore City Open Data portal to investigate whether there is a relationship between 311 service requests and vacant properties across city districts. The analysis reuses the CSV processing and profiling tools developed in Project 07.

---

## Dataset 1 — 311 Service Requests

- **Name:** Baltimore 311 Service Requests
- **Source:** https://data.baltimorecity.gov/
- **Description:** This dataset contains records of citizen-reported service requests submitted to Baltimore City, including issues such as housing complaints, infrastructure problems, and general city maintenance requests.
- **Key Columns Used:**
  - `district`
  - `service_request_type`
  - `status`

---

## Dataset 2 — Vacant Properties

- **Name:** Baltimore Vacant Properties
- **Source:** https://data.baltimorecity.gov/
- **Description:** This dataset contains information about properties classified as vacant or abandoned within Baltimore City, including their location and assigned district.
- **Key Columns Used:**
  - `district`
  - `vacant_properties`

---

## Research Question

Is there a relationship between the number of 311 service requests and the number of vacant properties across Baltimore City districts?

---

## Methodology

Both datasets were loaded and merged using the shared `district` field. After merging, the combined dataset was analyzed to compute correlations and compare districts based on:

- Number of 311 service requests
- Number of vacant properties

A correlation analysis was performed to measure the strength of the relationship between these two variables.

---

## Results

The analysis shows a positive correlation between 311 service requests and vacant properties across districts. Districts with higher numbers of vacant properties tend to also report more 311 service requests.

This suggests that areas with more abandoned or unmaintained properties also generate more resident complaints and maintenance requests.

---

## Limitations

- Correlation does not imply causation; we cannot conclude that vacant properties directly cause increased 311 requests.
- The dataset does not account for time-based trends or seasonal variation.
- Some 311 requests may be unrelated to vacant properties, introducing noise into the analysis.
- Data quality may vary depending on reporting accuracy and district coverage.

---

## Files Included

- `data/311.csv` — raw 311 service request data
- `data/vacant.csv` — vacant property dataset
- `src/analysis.py` — code used to join and analyze datasets
- `reports/output.txt` — output from CSV profiling and analysis

---

## Notes

This project reuses CSV processing and analysis components from Project 07, including structured data loading and error-handling patterns.
