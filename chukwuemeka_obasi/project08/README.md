# Project 8: Baltimore Surface Water Quality Correlation

This project reuses the `csvprof` code from [../project07](/Users/jess/COSC_352_SPRING_2026/chukwuemeka_obasi/project07) to profile two Baltimore open-data CSV files and then correlate them across time.

## Dataset 1

- Name: `Surface_Water_Quality_Data_2006_to_2015.csv`
- Source URL: `https://data.baltimorecity.gov/datasets/85f6cd8c0a8646d6b13239c83df51f83/about`
- Description: A date-filtered CSV export of Baltimore's Surface Water Quality dataset covering the earlier monitoring period. The file contains routine stream and harbor monitoring records from Baltimore Department of Public Works stations.
- Key columns used: `Station`, `Parameter`, `Unit`, `Result`, `datetime`

## Dataset 2

- Name: `Surface_Water_Quality_Data_2016_2025.csv`
- Source URL: `https://data.baltimorecity.gov/datasets/85f6cd8c0a8646d6b13239c83df51f83/about`
- Description: A second date-filtered CSV export from the same Baltimore portal dataset covering the later monitoring period. It contains the same station-level water-quality measurements and schema, which makes station-to-station comparison possible.
- Key columns used: `Station`, `Parameter`, `Unit`, `Result`, `datetime`

## Research Question

Did Baltimore monitoring stations that reported `E. Coli` in both files show lower median `E. Coli` readings in 2016-2025 than they did in 2006-2015?

## Profile Reports

- [reports/surface_water_quality_2006_2015_profile.txt](/Users/jess/COSC_352_SPRING_2026/chukwuemeka_obasi/project08/reports/surface_water_quality_2006_2015_profile.txt)
- [reports/surface_water_quality_2016_2025_profile.txt](/Users/jess/COSC_352_SPRING_2026/chukwuemeka_obasi/project08/reports/surface_water_quality_2016_2025_profile.txt)

## Answer

The joined analysis found 31 stations with numeric `E. Coli` measurements in both files. Of those 31 shared stations, 30 had a lower median `E. Coli` value in the 2016-2025 file and only 1 station had a higher median value. The median of the station medians dropped from `671.85 MPN/100ml` in the earlier file to `259.00 MPN/100ml` in the later file, for a median station-level change of `-360.50 MPN/100ml`.

The largest drop was at `CENTRAL & LANCASTER`, where the median fell from `11000.00` to `35.00 MPN/100ml`. The only increase was at `GWYNNS FALLS PKWY.`, where the median rose from `350.00` to `379.00 MPN/100ml`. Based on this cross-file comparison, the shared stations in this dataset generally show lower median `E. Coli` readings in the 2016-2025 period than in the 2006-2015 period.

## Limitations

- Both CSV files come from date-filtered exports of the same city dataset, so this is a longitudinal comparison rather than a comparison of two unrelated Baltimore systems.
- The number of samples per station is uneven across periods, which means some medians are based on many more observations than others.
- Some `Result` values in the older file are non-numeric strings such as `<2`; the program skips non-numeric values so that only comparable numeric `E. Coli` results are used.
- This analysis only measures station-level `E. Coli` changes and does not account for rainfall, seasonality, land-use changes, or sampling-method changes.

## Running The Code

From `project08`:

```bash
cargo run -- answer
```

To regenerate the committed profile reports:

```bash
cargo run -- profile
```
