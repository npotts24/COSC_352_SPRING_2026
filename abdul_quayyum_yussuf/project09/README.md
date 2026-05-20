# Project 09 — Rust Plotters Visualization

This project reads Baltimore City CSV data from `../project08/data` and uses the Rust `plotters` library to visualize profile statistics and correlation results.

## What it does

- Loads `project08` datasets:
  - `../project08/data/vacant_lots_per_neighborhood.csv`
  - `../project08/data/311_requests_2024.csv`
- Joins neighborhoods by normalized names.
- Computes correlation between vacant lot counts and 311 request counts.
- Loads local profile summary CSV data from `data/profile_metrics.csv`.
- Writes three PNG visualizations into `output/`.

## Output files

- `output/vacant_vs_requests.png` — scatter plot showing neighborhood vacant lots vs 311 request counts
- `output/top_neighborhood_requests.png` — bar chart of the top 10 neighborhoods by 311 requests
- `output/profile_metrics.png` — summary bar chart for profile statistics and correlation

## Run

From `project09/`:

```bash
cargo run --release
```

Then open the generated images in `project09/output/`.
