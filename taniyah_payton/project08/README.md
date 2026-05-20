# Project 8 — Cross-Dataset Correlation: 311 Resolution Speed × City Agency Salary Levels

Builds on [Project 7 `csvprof`](./csvprof/README.md).

---

## Repository Layout

```
project8/
├── Cargo.toml                        ← Cargo workspace (csvprof + balt-correlate)
├── README.md
├── data/
│   ├── 311_service_requests.csv      ← Dataset 1 (committed)
│   └── baltimore_salaries.csv        ← Dataset 2 (committed)
├── reports/
│   ├── 311_service_requests_profile.txt
│   └── baltimore_salaries_profile.txt
├── csvprof/                          ← Part 1 crate (library + binary)
│   └── src/lib.rs                    ← Only new file added to Part 1
└── balt-correlate/                   ← Part 2 crate
    └── src/main.rs
```

---

## Dataset 1 — Baltimore City 311 Customer Service Requests

| Field | Value |
|---|---|
| **File** | `data/311_service_requests.csv` |
| **Source URL** | https://data.baltimorecity.gov/City-Services/311-Customer-Service-Requests/9agw-sxsr |
| **Description** | Every 311 service request submitted to Baltimore City. Each row is one complaint or service call (pothole repair, missed trash, rodent complaint, street-light outage, etc.). The dataset includes the requesting channel, responsible city agency, police district, neighbourhood, and open/close timestamps. |
| **Key columns used** | `Agency` — join key (responsible city department); `CreatedDate` and `CloseDate` — used to compute days-to-close; `SRStatus` — filtered to `Closed` only |

---

## Dataset 2 — Baltimore City Employee Salaries

| Field | Value |
|---|---|
| **File** | `data/baltimore_salaries.csv` |
| **Source URL** | https://data.baltimorecity.gov/City-Government/Baltimore-City-Employee-Salaries/6xv6-e66h |
| **Description** | Annual salary and gross-pay records for all Baltimore City employees, covering FY2011–FY2024. Each row is one employee; includes their job class, agency, hire date, annual salary, and actual gross pay received. |
| **Key columns used** | `agencyName` — join key (must match `Agency` in 311 data); `grossPay` — actual compensation paid in the fiscal year |

---

## Research Question

Do Baltimore City agencies whose employees earn higher average gross pay resolve 311 service requests more quickly (fewer days between `CreatedDate` and `CloseDate`)?

---

## How to Build and Run

```bash
# From the workspace root (project8/)
cargo build --release

# Run the correlation (paths default to data/)
./target/release/balt-correlate

# Also show csvprof column summaries for both files
./target/release/balt-correlate --profile

# Override paths
./target/release/balt-correlate \
  --requests path/to/311.csv \
  --salaries path/to/salaries.csv

# Part 1 tool still works as before
./target/release/csvprof data/311_service_requests.csv
./target/release/csvprof data/baltimore_salaries.csv --format json
```

---

## How Part 1 Code Is Reused

`balt-correlate` declares `csvprof` as a path dependency and calls the following Part 1 symbols directly. No CSV reading, null detection, type inference, or profiling logic is reimplemented.

| Part 1 symbol | Module | Used for in Part 2 |
|---|---|---|
| `CsvIngestor::ingest` | `csvprof::ingest` | Streaming column-oriented CSV reading for both input files |
| `ProfilerError::FileNotFound` | `csvprof::error` | Surfacing missing-file errors without reimplementing error types |
| `is_null` | `csvprof::types` | Skipping empty/null cells while iterating column values |
| `infer_type` | `csvprof::types` | Column type inference when `--profile` flag is set |
| `Profiler` trait | `csvprof::profile` | Trait bound for the profiler dispatch |
| `DispatchProfiler` | `csvprof::profilers` | Producing per-column profiles under `--profile` |
| `ProfilerOptions` | `csvprof::profile` | Options struct forwarded to `DispatchProfiler` |
| `report::print_report` | `csvprof::report` | Human-readable column summary output |

---

## Answer

Running `./target/release/balt-correlate` against the committed data files produces:

```
Loaded 120 closed 311 requests and 114 salary records.

  Agency                              Avg Gross Pay    Employees  Avg Days to Close  311 Requests
  Housing & Community Development     $69,072          21         22.8               35
  Transportation                      $67,436          11         15.6               52
  Public Works                        $55,617          29          1.0               33

  Pearson r (avg agency pay vs avg days to close): 0.9762
  Interpretation: strong positive correlation

  → Agencies with higher average gross pay do NOT close requests faster —
    higher pay correlates with slower closure.

  Fastest average resolution:
    Public Works                          1.0 days  (avg pay $55,617)
  Slowest average resolution:
    Housing & Community Development      22.8 days  (avg pay $69,072)
```

**What the data shows:** The Pearson correlation between average agency gross pay and average days to close is **r = 0.98**, a strong *positive* correlation — meaning the higher-paid agencies resolve requests *more slowly*, not faster. Public Works (avg pay ~$55,600) closes requests in just 1.0 day on average, while Housing & Community Development (avg pay ~$69,100) takes 22.8 days. Transportation sits in between at 15.6 days and ~$67,400 average pay.

The finding is counter-intuitive but explainable: resolution speed is largely determined by the nature of the work itself, not staffing compensation. A missed trash pickup (Public Works) is closed the next day by design. A rodent complaint or code enforcement action (Housing & Community Development) requires inspection, notice, re-inspection, and often legal follow-up — a multi-week workflow regardless of how much inspectors are paid. The correlation is therefore spurious in causal terms; it reflects differences in *request type complexity* across agencies more than it reflects anything about pay.

---

## Limitations

1. **Request type confounds the result entirely.** The dominant driver of resolution time is the type of service request, not the agency's pay level. Public Works handles trash and potholes (fast by definition); HCD handles code enforcement (slow by definition). Salary level and request type co-vary with agency, making it impossible to isolate the effect of pay.

2. **Only three agencies matched.** The inner join produces just three data points, making the Pearson r statistically meaningless — a single outlier would flip the sign. A proper analysis would need dozens of matched agencies.

3. **`grossPay` includes overtime.** Agencies with more overtime-eligible positions (e.g., Public Works sanitation crews) have inflated gross pay relative to base salary, which doesn't reflect total departmental investment.

4. **Fiscal year mismatch.** The salary data is from FY2024 (ending June 30, 2024) while the 311 data covers calendar-year 2024. Requests from July–December 2024 are matched against salaries from a slightly different period.
