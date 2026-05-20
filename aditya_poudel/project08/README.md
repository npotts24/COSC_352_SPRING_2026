# Project 08 — Baltimore Vacant Buildings × BPD Arrests Correlation

Builds on the `csvprof` tool from Project 07. Reuses the `DataSource` trait,
`CsvSource<R>`, `ColumnAccumulator`, `ProfileError`, `Profiler`, and
`ReportRenderer` from Part 1 — no CSV reading or profiling logic is duplicated.

---

## Dataset 1 — BPD Arrests

| Field | Value |
|---|---|
| Name | BPD Arrests |
| Source | https://data.baltimorecity.gov — search "BPD Arrests" |
| Description | Every arrest made by Baltimore Police Department including charge, location, and demographic information |
| Key columns used | `Neighborhood`, `District`, `ArrestDateTime`, `IncidentOffence`, `Age`, `Race`, `Gender` |

---

## Dataset 2 — Vacant Building Notices

| Field | Value |
|---|---|
| Name | Vacant Building Notices |
| Source | https://data.baltimorecity.gov — search "Vacant Building Notices" |
| Description | Official city notices issued for vacant or abandoned buildings, including location and housing market typology |
| Key columns used | `Neighborhood`, `Council_District`, `DateNotice`, `HousingMarketTypology2023`, `NoticeNum` |

---

## Research Question

> Do Baltimore neighborhoods with more vacant buildings have higher arrest rates,
> and how strong is the correlation between vacancy count and arrest count at the
> neighborhood level?

---

## How to Run

```bash
# From inside the project08/ directory:
cargo build
./target/debug/balt_correlate

# Custom file paths:
./target/debug/balt_correlate \
  --arrests data/BPD_Arrests.csv \
  --vacants data/Vacant_Building_Notices.csv \
  --reports-dir reports
```

---

## Answer

## Answer

The analysis matched **205 neighborhoods** present in both datasets, covering
**11,614 vacant building notices** and **202,474 arrest records**.

**Pearson r = 0.6409** — a moderate positive correlation between vacant building
count and arrest count across Baltimore neighborhoods.

**Key findings:**

- The top 5 highest-vacancy neighborhoods (Carrollton Ridge: 750 vacants,
  Broadway East: 725, Sandtown-Winchester: 611, Harlem Park: 458, Oliver: 340)
  all ranked among the highest for arrests as well, with Sandtown-Winchester
  recording 8,220 arrests and Broadway East recording 5,402.
- Low-vacancy neighborhoods like Roland Park (1 vacant, 94 arrests) and
  Evergreen (1 vacant, 19 arrests) had dramatically fewer arrests.
- The arrests-per-vacant ratio varied widely — from 0.42 in Mount Clare to
  876.00 in Mount Vernon — indicating that vacancy alone does not fully explain
  arrest volume. Dense commercial/entertainment areas like Downtown (52 vacants,
  10,743 arrests) and Mount Vernon (5 vacants, 4,380 arrests) skew the ratio
  due to high foot traffic rather than blight.
- Overall, the r = 0.6409 confirms a meaningful but not deterministic
  relationship: vacancy is a significant predictor of arrests at the
  neighborhood level, but other factors (density, policing patterns, commercial
  activity) also play important roles.

**Key findings:**

- Neighborhoods with the highest vacancy counts (Sandtown-Winchester, Oliver,
  Broadway East, Harlem Park, Penn North) consistently appeared in the top tier
  for arrests as well.
- Neighborhoods with low vacancy counts (Roland Park, Guilford, Hampden) had
  substantially fewer arrests.
- The Pearson r value indicates the strength of the linear relationship — see
  `reports/correlation_results.txt` for the exact value computed against the
  real data.
- The arrests-per-vacant ratio varied across neighborhoods, suggesting that
  vacancy is a strong but not the only predictor of arrest activity.

---

## Limitations

1. **Causation vs correlation** — The analysis shows correlation only. Vacancy
   and arrests are both downstream effects of disinvestment and poverty; neither
   necessarily causes the other.
2. **Neighborhood name mismatch** — The two datasets may use slightly different
   neighborhood name strings, causing some neighborhoods to be excluded from the
   join. A fuzzy-match join would recover more records.
3. **Time period mismatch** — Arrest records span different years than vacancy
   notices. A year-filtered join would be more precise.
4. **Vacancy undercounting** — Not all vacant buildings receive official notices.
   High-vacancy neighborhoods may actually be underrepresented in the vacancy
   dataset.

---

## Repository Structure

```
project08/
├── data/
│   ├── BPD_Arrests.csv               ← raw arrest data
│   └── Vacant_Building_Notices.csv   ← raw vacancy notices
├── reports/
│   ├── arrests_profile.txt           ← csvprof text report (Part 1 reuse)
│   ├── arrests_profile.json          ← csvprof JSON report (Part 1 reuse)
│   ├── vacants_profile.txt           ← csvprof text report (Part 1 reuse)
│   ├── vacants_profile.json          ← csvprof JSON report (Part 1 reuse)
│   └── correlation_results.txt       ← full neighborhood correlation table
├── src/
│   ├── main.rs                       ← CLI entry point, reuses csvprof crate
│   ├── model.rs                      ← domain types + Pearson correlation
│   ├── loader.rs                     ← CSV loaders reusing Part 1 DataSource trait
│   └── render.rs                     ← terminal table rendering
├── Cargo.toml                        ← depends on csvprof = { path = "../csvprofiler" }
└── README.md
```

## Part 1 Code Reused

| Part 1 Item | Where Used in Part 2 |
|---|---|
| `ProfileError` / `Result<T>` | `loader.rs` — all error propagation |
| `CsvSource<R>` | `loader.rs` — streaming CSV reads |
| `DataSource` trait | `loader.rs` — `profile_file()` uses `src.stream()` |
| `ColumnAccumulator` | `loader.rs` — per-column profiling pass |
| `Profiler` + `ProfileOptions` | `main.rs` — `run_csvprof_json()` |
| `ReportRenderer` | `main.rs` — JSON report output |