# Project 08 — Baltimore City Open Data Analysis

## Datasets

### Dataset 1: 311 Customer Service Requests 2024
- Source URL: https://www.arcgis.com/home/item.html?id=3473298b30c040f9ba42ada171bac500
- Description: A Baltimore City open data feature service containing 311 customer service request records for 2024.
- Key columns used:
  - `Neighborho` — neighborhood name for the request
  - `SRType` — service request type
  - `Address` — request location address
  - `ZipCode` — postal code
  - `CreatedDat` — date of request creation

### Dataset 2: Vacant Lots per Neighborhood
- Source URL: https://www.arcgis.com/home/item.html?id=5b0085e92740432180d170ce85a7fd7e
- Description: A neighborhood-level summary dataset reporting the number of vacant lots in each Baltimore neighborhood.
- Key columns used:
  - `NBRDESC` — neighborhood name used for vacant lot counts
  - `VacantLots` — count of vacant lots in the neighborhood

## Research Question

Do Baltimore neighborhoods with more vacant lots have more 311 service requests in 2024?

## Approach

- Downloaded both datasets as CSV files into `data/`.
- Used the Part 1 `csvprof` code from `project07/csvprof` by importing its shared library types and functions.
- Normalized neighborhood names in both datasets by lowercasing and removing non-alphanumeric characters, then joined on that normalized key.
- Aggregated 311 requests by neighborhood and joined that with vacant lot counts.
- Calculated a Pearson correlation coefficient to measure the numeric relationship.

## Answer

The analysis joined 271 Baltimore neighborhoods and found a Pearson correlation coefficient of **-0.0238** between vacant lot count and 311 request count.

That coefficient is essentially zero, meaning the data show no clear positive relationship between the number of vacant lots and the number of 311 requests in 2024.

Example values from the joined output:
- `ABELL`: 1 vacant lot, 94 requests
- `WINCHESTER`: 3 vacant lots, 251 requests
- `PARK CIRCLE`: 6 vacant lots, 358 requests
- `DOWNTOWN`: 9 vacant lots, 471 requests

This shows that high 311 request counts can occur in neighborhoods with few vacant lots, and neighborhoods with many vacant lots do not necessarily have more requests.

## Limitations

- Neighborhood names are normalized to join the datasets, but this may mask naming inconsistencies or areas that do not align perfectly.
- The analysis uses only 2024 311 requests, so it is a single-year snapshot.
- The datasets do not capture request severity, request type, or whether the vacant lots caused the request.
- There may be other confounding factors such as population density or land use that the analysis does not control for.

## Files in this project

- `data/311_requests_2024.csv`
- `data/vacant_lots_per_neighborhood.csv`
- `reports/311_requests_profile_report.json`
- `reports/vacant_lots_profile_report.json`
- `src/main.rs` — analysis program that joins both datasets and computes correlation
