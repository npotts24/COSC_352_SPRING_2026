# csvprof — Streaming CSV Data Profiler + Baltimore City Analysis

## Part 1: CSV Profiling CLI Tool

A command-line data profiling tool written in idiomatic Rust. Streams any CSV
file and produces a structured report — types, statistics, and quality warnings
— without loading the whole file into memory.

### Build

```bash
cargo build --release
```

### Usage

```bash
./target/release/csvprof [OPTIONS] <FILE>

Options:
  -p, --percentiles     Show p5/p25/p75/p95 for numeric columns
  -H, --histogram       Show full frequency histogram for categoricals
  -j, --json            Output as JSON
  -d, --delimiter       Field delimiter (default: comma)
  -h, --help            Print help
```

---

## Part 2: Baltimore City Open Data Analysis

### Dataset 1 — Gun Offenders Registry

- **Source:** https://data.baltimorecity.gov/datasets/gun-offenders
- **Description:** Registry of individuals convicted of gun offenses in Baltimore
  City, including their address, police district, neighborhood, and ZIP code.
  Each row is one registered offender.
- **Key columns used:** `ZipCode` (join key), `District` (police district label)
- **File:** `data/Gun_Offenders.csv` — 4,521 records, 23 columns

### Dataset 2 — Liquor Licenses

- **Source:** https://data.baltimorecity.gov/datasets/liquor-licenses
- **Description:** All liquor license applications and renewals issued by the
  Baltimore City Board of Liquor License Commissioners. Covers taverns, restaurants,
  retail beer/wine stores, and other establishment types. Each row is one license
  record (a single establishment may appear multiple times across years).
- **Key columns used:** `AddrZip` (join key), `LicenseStatus` (filtered to
  Active/Renewed only)
- **File:** `data/Liquor_Licenses.csv` — 29,751 records, 21 columns

---

### Research Question

Do Baltimore ZIP codes with a higher density of active liquor licenses have a
higher concentration of registered gun offenders?

---

### Running the Analysis

```bash
cargo build --release

# Profile both files individually (Part 1)
./target/release/csvprof data/Gun_Offenders.csv
./target/release/csvprof data/Liquor_Licenses.csv

# Run the correlation analysis (Part 2)
./target/release/analyze
```

---

### Answer

The analysis joins both datasets on ZIP code and computes a Pearson correlation
between active liquor license count and registered gun offender count per ZIP.

**Key findings:**

| ZIP   | District   | Active Licenses | Gun Offenders |
|-------|------------|-----------------|---------------|
| 21215 | NORTHERN   | 988             | 375           |
| 21213 | SOUTHEAST  | 1022            | 308           |
| 21216 | NORTHWEST  | 456             | 300           |
| 21202 | CENTRAL    | 3967            | 123           |
| 21231 | CENTRAL    | 2800            | 40            |
| 21210 | NORTHERN   | 360             | 3             |

**Pearson r = 0.096** — a weak positive correlation overall.

The data does not support a strong link between liquor license density and gun
offender concentration at the ZIP code level. ZIP 21215 (Northern district) has
a high offender count (375) with a moderate license count (988), while ZIP 21202
(Downtown/Central) has the most licenses (3,967) but only 123 offenders. This
suggests that high commercial activity alone does not predict gun offender
registration. The highest offender ZIPs — 21215, 21213, 21216, 21217 — are
residential neighborhoods in historically under-resourced districts (Northern,
Western, Northwest), not the high-density commercial zones.

---

### Limitations

1. **Liquor licenses are historical, not point-in-time.** The dataset includes
   all renewals across years. A ZIP with many licenses accumulated over decades
   looks similar to one with a recent surge, which affects the correlation.

2. **Gun offender registry reflects enforcement, not incidence.** ZIPs with more
   active policing may show higher registration rates independent of actual
   firearm activity.

3. **ZIP code is a coarse geographic unit.** Joining on ZIP code flattens
   neighborhood-level variation. A block-level analysis using lat/lon coordinates
   (available in the gun offenders dataset) would be more precise.

---

### Architecture

```
src/
├── main.rs          csvprof CLI entry point (Part 1)
├── analyze.rs       Part 2 correlator — reuses Part 1 modules
├── accumulator.rs   ColumnAccumulator + Profiler trait  ← reused in analyze.rs
├── types.rs         InferredType, ColumnProfile, etc.   ← reused in analyze.rs
├── infer.rs         Type inference pure functions
├── cli.rs           CLI flag definitions
├── report.rs        Terminal table renderer
├── profiler.rs      Generic CSV orchestration
└── error.rs         CsvProfError (thiserror)            ← reused in analyze.rs

data/
├── Gun_Offenders.csv
└── Liquor_Licenses.csv

reports/
├── gun_offenders_profile.txt
└── liquor_licenses_profile.txt
```

### Part 1 Code Reused in Part 2

| Component | Where used |
|---|---|
| `ColumnAccumulator` | Streams and profiles every column while loading data |
| `AccumulatorConfig` | Configures accumulator thresholds |
| `InferredType` enum | Displays column type summaries in analyze output |
| `Profiler` trait | Implemented by `ColumnAccumulator`, called via `finalize()` |
| `anyhow`/`CsvProfError` | Error propagation with context chains throughout |