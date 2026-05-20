# Part 2: Baltimore City Open Data Analysis

## Dataset 1: Housing and Building Permits (2019–Present)

- **Name:** Housing and Building Permits
- **Source URL:** https://data.baltimorecity.gov/datasets/fesm-tgxf
- **Description:** Records of all building and housing permits issued by Baltimore City since 2019. Each row represents one permit application.
- **Key columns:**
  - `CaseNumber` — unique permit ID
  - `IssuedDate` — date the permit was issued
  - `Neighborhood` — Baltimore neighborhood where the work is permitted
  - `Cost` — estimated cost of the work in dollars
  - `IsPermitModification` — 1 if this is a modification of an existing permit, 0 if original

## Dataset 2: Vacant Building Notices

- **Name:** Vacant Building Notices
- **Source URL:** https://data.baltimorecity.gov/datasets/qqcv-ihn5
- **Description:** Records of all vacant building notices issued by Baltimore City Housing. Each row represents one property that has been officially flagged as vacant.
- **Key columns:**
  - `NoticeNum` — unique notice ID
  - `DateNotice` — date the vacant notice was issued
  - `Neighborhood` — Baltimore neighborhood where the vacant property is located
  - `Address` — street address of the vacant property

## Research Question

Do Baltimore neighborhoods with more building permits issued have fewer vacant buildings?

## Answer

The analysis found a weak positive correlation (Pearson r = 0.4009) between permit counts and vacant building counts by neighborhood. This means neighborhoods with more permits tend to also have more vacants — the opposite of a simple "investment reduces blight" story. However, this is partly explained by neighborhood size: larger, more active neighborhoods generate both more permits and more vacant notices. Canton, the most permitted neighborhood (6,087 permits), had only 19 vacant notices, while Carrollton Ridge, the most vacant neighborhood (753 notices), had only 1,891 permits — suggesting that the most heavily invested neighborhoods do successfully avoid high vacancy, but that permit activity alone does not predict low vacancy across all neighborhoods.

## Limitations

- **Neighborhood size is a confound.** Larger neighborhoods naturally produce more of both permits and vacant notices, which inflates the positive correlation. A per-capita or per-parcel rate would give a fairer comparison.
- **Permits do not equal completed work.** A permit being issued does not mean construction was finished or that the property improved. Many permits may have expired or been abandoned.
- **Vacant notices are not a complete count of vacancy.** A property must be officially reported and inspected to receive a notice. Actual vacancy rates are likely higher than what this dataset captures.
- **Time ranges differ.** Building permits cover 2019–present while vacant notices go back to 2008, so the two datasets do not cover the same period, making direct before/after comparisons unreliable.

## How to Run

```bash
# Profile both datasets
cargo run --bin csvprof -- data/building_permits.csv > reports/building_permits_profile.txt
cargo run --bin csvprof -- data/vacant_buildings.csv > reports/vacant_buildings_profile.txt

# Run the correlation analysis
cargo run --bin analyze > reports/analysis_output.txt
```

## Part 1 Code Reuse

`src/main.rs` reuses the following from Part 1 (`src/csvprof.rs`):

- **`ColumnAnalyzer` trait** — defines the `feed`, `count`, and `null_count` interface, mirroring the Part 1 `ColStats` feed pattern
- **`CategoryCounter`** — implements `ColumnAnalyzer` using the same `HashMap<String, u64>` value-counts logic as Part 1's `ColStats`
- **Streaming reader pattern** — `open_csv` returns `Box<dyn Read>`, the same stdin/file abstraction used in Part 1