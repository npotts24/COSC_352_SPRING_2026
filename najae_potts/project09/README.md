**Project 09 — CSV Profiler & Visualizer**

This crate profiles CSV datasets and produces visualizations using the Rust `plotters` library. It reproduces the CSV profiling behavior from `project08` and adds PNG charts that show statistics and correlations across the two datasets.

**Goal**: Produce JSON profile summaries and PNG visualizations for the two CSVs in `project08/data` (or copied into `project09/project09/data`). Visualizations include top ZIPs and neighborhoods, license-fee scatter, and a year-by-year comparison of license counts vs vacant-building rehabs.

**Repository layout**
- **`project09/project09/src/main.rs`**: main program that builds profiles and plots.
- **`project09/project09/data/`**: expected CSV inputs (`Liquor_Licenses.csv`, `Vacant_Building_Rehabs.csv`).
- **`project09/project09/reports/`**: JSON profile outputs (e.g. `Liquor_Licenses_profile.json`).
- **`project09/project09/output/`**: PNG visualizations (e.g. `top_zips_licenses.png`, `year_comparison.png`).

**Dependencies**
- Rust crates (declared in `project09/project09/Cargo.toml`):
	- **csv**: CSV parsing
	- **serde**, **serde_json**: JSON serialization for profiles
	- **plotters** (and backend): plotting PNGs
	- **anyhow**: error handling
- System packages required for `plotters` font handling (Linux / Debian/Ubuntu):
	- `pkg-config`
	- `libfontconfig1-dev`

Install system deps (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install -y pkg-config libfontconfig1-dev
```

If `fontconfig` isn't available on your OS, install the equivalent development package for your distribution or configure `PKG_CONFIG_PATH` to point to the directory containing `fontconfig.pc`.

How to run
- Copy CSVs from `project08` into this crate (or ensure the program can read `../../project08/data/`):
```bash
mkdir -p project09/project09/data
cp project08/data/*.csv project09/project09/data/
```
- Build and run the program (from workspace root or inside the crate):
```bash
cd project09/project09
cargo build
cargo run --release
```

Expected outputs
- JSON profiles: `project09/project09/reports/`
	- `Liquor_Licenses_profile.json`
	- `Vacant_Building_Rehabs_profile.json`
- PNG visualizations: `project09/project09/output/`
	- `top_zips_licenses.png`
	- `top_neighborhoods_rehabs.png`
	- `year_comparison.png`
	- `license_fee_scatter.png`

Troubleshooting
- If the build fails with a `fontconfig`/`pkg-config` error, install the system packages above.
- If CSV headers differ, update the column names in `project09/project09/src/main.rs` (the code uses header names like `AddrZip`, `LicenseFee`, `LicenseYear`, `DateIssue`, and `Neighborhood`).

Next ideas
- Add CLI flags to pick which plots to generate, change `top-N` counts, or output formats.
- Join datasets by geographic key (ZIP → neighborhood) for richer correlations (requires address/geocoding mapping).

If you want, I can commit this README to git and open the generated PNGs inline. 

