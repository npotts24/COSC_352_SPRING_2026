# Project 08 — Baltimore City Open Data Analysis

Builds on the `csvprof` tool from Project 07.

---

## Dataset 1 — 311 Customer Service Requests 2024

| Field | Value |
|---|---|
| **Name** | 311 Customer Service Requests 2024 |
| **Source URL** | <https://data.baltimorecity.gov/datasets/68a1136acff444bba6c93e845dfc00e1> |
| **API Endpoint** | `https://services1.arcgis.com/UWYHeuuJISiGmgXx/arcgis/rest/services/311_Customer_Service_Requests_2024/FeatureServer/0` |
| **Local file** | `data/311_requests.csv` |
| **Rows** | 2,000 (first 2,000 of 2024) |
| **Description** | Resident service requests submitted to Baltimore City via the 311 system. Each row is one request and includes the request type, geographic identifiers, status, and timestamps. |

**Key columns used:**

- `SRType` — the category of the service request (e.g., "SW-Graffiti Removal", "HCD-Illegal Dumping")
- `Neighborhood` — Baltimore City neighborhood name; 37.3 % of rows have no neighborhood value
- `PoliceDistrict` — police district in which the request was filed
- `CouncilDistrict` — council district number
- `SRStatus` — current status of the request (Closed, Open, etc.)
- `Agency` — city agency responsible for handling the request

---

## Dataset 2 — Vacant Building Notices

| Field | Value |
|---|---|
| **Name** | Vacant Building Notices |
| **Source URL** | <https://data.baltimorecity.gov/datasets/Vacant-Building-Notices> |
| **API Endpoint** | `https://egisdata.baltimorecity.gov/egis/rest/services/Housing/DHCD_Open_Baltimore_Datasets/FeatureServer/1` |
| **Local file** | `data/vacant_building_notices.csv` |
| **Rows** | 1,000 (active notices) |
| **Description** | Official notices issued by Baltimore's Department of Housing and Community Development (DHCD) designating properties as vacant buildings. Each row is one notice for a specific address. A notice remains "open" until it is either abated (building rehabilitated/demolished — `DateAbate`) or cancelled (`DateCancel`). |

**Key columns used:**

- `NoticeNum` — unique identifier for the notice
- `Neighborhood` — Baltimore City neighborhood where the vacant building is located
- `DateNotice` — date the notice was issued (Unix timestamp)
- `DateAbate` — date the notice was resolved via abatement; empty = still open
- `DateCancel` — date the notice was cancelled; empty = still open
- `Council_District` — council district number
- `Address` — street address of the vacant property

---

## Research Question

> Do Baltimore neighborhoods with a higher concentration of **open Vacant Building Notices** also generate more **311 service requests**?

The hypothesis is that physical blight — indicated by open vacant building notices — correlates with increased resident complaints routed through the 311 system.

---

## Running the Program

```bash
# From the project08/ directory
cargo run
```

The binary expects `data/311_requests.csv` and `data/vacant_building_notices.csv` in the working directory (both are committed to this repository). No additional downloads are needed.

---

## Part 1 Code Reuse

This program imports and calls the following items from the `csvprof` library (Project 07):

| Part 1 Item | Where used in Part 2 |
|---|---|
| `csvprof::stats::Profiler` trait | Imported explicitly; `push()` and `finish()` called on every column of the 311 file |
| `csvprof::stats::ColumnAccumulator` | Instantiated once per column to accumulate raw values and produce quality flags |
| `csvprof::reader::profile_csv` | Called on both CSV files to stream-profile all columns |
| `csvprof::error::CsvProfError` | Used as the unified error type throughout; `CsvProfError::Csv` and `CsvProfError::NoColumns` variants are both used |
| `csvprof::error::Result<T>` | Return type of every function in Part 2 |

The csvprof crate is referenced as a path dependency:

```toml
[dependencies]
csvprof = { path = "../project07/csvprof" }
```

---

## Answer

Running `cargo run` produces the following summary statistics:

```
Neighborhoods in both datasets : 233
Total 311 requests             : 1,254
Total open vacant notices      : 994
Pearson r (311 vs vacants)     : 0.3960

FINDING: Moderate positive correlation — neighborhoods with
more open vacant buildings show a moderate increase in 311
service requests (r = 0.3960).
```

**Written explanation:**

The Pearson r of **0.396** indicates a statistically meaningful, moderate positive correlation between the number of open Vacant Building Notices and the volume of 311 service requests within a neighborhood.

The clearest signal appears at the top of the distribution. **Sandtown-Winchester** — Baltimore's neighborhood with the most open notices in this sample (324) — also produced 30 requests, the highest among matched neighborhoods. Similarly, **Harlem Park** (99 notices, 16 requests) and **Easterwood** (87 notices, 5 requests) both rank near the top on both dimensions. **Carrollton Ridge**, with 75 open notices, generated the most 311 requests of any single neighborhood (54), suggesting that in some heavily-blighted areas residents are especially engaged in reporting issues.

The relationship is not strictly linear, however: many neighborhoods with zero matched vacant-building notices still generate double-digit 311 requests (e.g., Belair-Edison, Brooklyn, Walbrook), indicating that 311 activity also reflects a wide range of non-blight concerns (traffic, graffiti, solid waste). The correlation captures the blight-driven component of 311 activity but does not explain the full picture.

---

## Limitations

1. **Dataset size and scope.** Both datasets were limited to 1,000–2,000 rows by the API. The 311 file represents only the first 2,000 requests of 2024, not the full year; the vacant building notices are a snapshot of current open notices, not all historical notices. A full-year or multi-year pull could reveal different patterns.

2. **Temporal mismatch.** The 311 requests are from 2024, but some Vacant Building Notices in the sample date back to 2009. The analysis treats the two datasets as contemporaneous, but a building that was declared vacant in 2010 and still has an open notice may not reflect the current blight level in a neighborhood.

3. **Neighborhood name matching.** The join is done on exact string equality. Inconsistent spellings or missing values (37 % of 311 rows lack a neighborhood) reduce the effective sample and could bias results toward neighborhoods that are both well-mapped and active reporters.

4. **Ecological fallacy.** The unit of analysis is the neighborhood, not the individual building or household. A neighborhood-level correlation cannot tell us whether the 311 requests are being made by residents who live near or are directly affected by specific vacant buildings.

---

## Repository Layout

```
project08/
├── data/
│   ├── 311_requests.csv             # 311 Customer Service Requests 2024 (2,000 rows)
│   └── vacant_building_notices.csv  # Vacant Building Notices, open notices (1,000 rows)
├── reports/
│   ├── 311_requests_profile.txt     # csvprof output for Dataset 1
│   └── vacant_building_notices_profile.txt  # csvprof output for Dataset 2
├── src/
│   └── main.rs                      # Correlation analysis program
├── Cargo.toml
└── README.md
```
