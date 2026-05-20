use std::collections::{BTreeMap, BTreeSet};
use std::fs;

use csv::StringRecord;
use csvprof::{open_csv_reader, ColumnSummary, CsvProfError, CsvProfiler, TypeBasedProfilerFactory};

const EARLY_DATASET: &str = "data/Surface_Water_Quality_Data_2006_to_2015.csv";
const LATE_DATASET: &str = "data/Surface_Water_Quality_Data_2016_2025.csv";
const EARLY_REPORT: &str = "reports/surface_water_quality_2006_2015_profile.txt";
const LATE_REPORT: &str = "reports/surface_water_quality_2016_2025_profile.txt";
const TARGET_PARAMETER: &str = "E. Coli";
const TARGET_UNIT: &str = "MPN/100ml";

struct StationChange {
    station: String,
    early_samples: usize,
    late_samples: usize,
    early_median: f64,
    late_median: f64,
    delta: f64,
}

fn main() -> Result<(), CsvProfError> {
    match std::env::args().nth(1).as_deref() {
        None | Some("answer") => run_analysis(),
        Some("profile") => write_profile_reports(),
        Some(other) => Err(CsvProfError::Message(format!(
            "unknown command '{other}'. Use 'answer' or 'profile'."
        ))),
    }
}

fn write_profile_reports() -> Result<(), CsvProfError> {
    let profiler = CsvProfiler::new(TypeBasedProfilerFactory);
    fs::create_dir_all("reports")?;

    let early_profile = profiler.analyze_file(EARLY_DATASET)?;
    let late_profile = profiler.analyze_file(LATE_DATASET)?;

    fs::write(
        EARLY_REPORT,
        render_profile_report("Surface Water Quality Data 2006 to 2015", &early_profile),
    )?;
    fs::write(
        LATE_REPORT,
        render_profile_report("Surface Water Quality Data 2016 to 2025", &late_profile),
    )?;

    println!("Wrote {EARLY_REPORT}");
    println!("Wrote {LATE_REPORT}");
    Ok(())
}

fn run_analysis() -> Result<(), CsvProfError> {
    let early = load_station_results(EARLY_DATASET)?;
    let late = load_station_results(LATE_DATASET)?;
    let changes = correlate_station_medians(&early, &late)?;

    let improved = changes.iter().filter(|change| change.delta < 0.0).count();
    let worsened = changes.iter().filter(|change| change.delta > 0.0).count();
    let unchanged = changes.len() - improved - worsened;

    let early_station_medians: Vec<f64> = changes.iter().map(|change| change.early_median).collect();
    let late_station_medians: Vec<f64> = changes.iter().map(|change| change.late_median).collect();
    let median_shift = median(changes.iter().map(|change| change.delta).collect())?;

    let largest_drop = changes
        .first()
        .ok_or_else(|| CsvProfError::Message("no shared stations found".to_string()))?;
    let largest_increase = changes
        .iter()
        .rev()
        .find(|change| change.delta > 0.0)
        .or_else(|| changes.last())
        .ok_or_else(|| CsvProfError::Message("no shared stations found".to_string()))?;

    println!("Research question:");
    println!(
        "Did Baltimore stations with E. Coli measurements in both files show lower median E. Coli readings in 2016-2025 than they did in 2006-2015?"
    );
    println!();
    println!("Shared stations analyzed: {}", changes.len());
    println!("Stations with lower median E. Coli in 2016-2025: {improved}");
    println!("Stations with higher median E. Coli in 2016-2025: {worsened}");
    println!("Stations with no change: {unchanged}");
    println!(
        "Median of station medians in 2006-2015: {:.2} {TARGET_UNIT}",
        median(early_station_medians)?
    );
    println!(
        "Median of station medians in 2016-2025: {:.2} {TARGET_UNIT}",
        median(late_station_medians)?
    );
    println!("Median station-level shift: {:.2} {TARGET_UNIT}", median_shift);
    println!();
    println!(
        "Largest drop: {} ({:.2} -> {:.2}, delta {:.2}; samples {} vs {})",
        largest_drop.station,
        largest_drop.early_median,
        largest_drop.late_median,
        largest_drop.delta,
        largest_drop.early_samples,
        largest_drop.late_samples
    );
    println!(
        "Only increase: {} ({:.2} -> {:.2}, delta {:.2}; samples {} vs {})",
        largest_increase.station,
        largest_increase.early_median,
        largest_increase.late_median,
        largest_increase.delta,
        largest_increase.early_samples,
        largest_increase.late_samples
    );
    println!();
    println!("Five biggest drops:");
    for change in changes.iter().take(5) {
        println!(
            "- {}: {:.2} -> {:.2} ({:.2})",
            change.station, change.early_median, change.late_median, change.delta
        );
    }

    Ok(())
}

fn load_station_results(path: &str) -> Result<BTreeMap<String, Vec<f64>>, CsvProfError> {
    let mut reader = open_csv_reader(path)?;
    let headers = reader.headers()?.clone();
    let station_index = column_index(&headers, "Station")?;
    let parameter_index = column_index(&headers, "Parameter")?;
    let unit_index = column_index(&headers, "Unit")?;
    let result_index = column_index(&headers, "Result")?;

    let mut values_by_station: BTreeMap<String, Vec<f64>> = BTreeMap::new();

    for record in reader.records() {
        let record = record?;
        let parameter = record.get(parameter_index).unwrap_or("").trim();
        let unit = record.get(unit_index).unwrap_or("").trim();

        if parameter != TARGET_PARAMETER || unit != TARGET_UNIT {
            continue;
        }

        let station = record.get(station_index).unwrap_or("").trim();
        let raw_result = record.get(result_index).unwrap_or("").trim();

        if station.is_empty() || raw_result.is_empty() {
            continue;
        }

        if let Ok(value) = raw_result.parse::<f64>() {
            values_by_station
                .entry(station.to_string())
                .or_default()
                .push(value);
        }
    }

    Ok(values_by_station)
}

fn correlate_station_medians(
    early: &BTreeMap<String, Vec<f64>>,
    late: &BTreeMap<String, Vec<f64>>,
) -> Result<Vec<StationChange>, CsvProfError> {
    let shared_stations: BTreeSet<_> = early.keys().cloned().collect::<BTreeSet<_>>()
        .intersection(&late.keys().cloned().collect())
        .cloned()
        .collect();

    let mut changes = Vec::new();

    for station in shared_stations {
        let early_values = early
            .get(&station)
            .ok_or_else(|| CsvProfError::Message(format!("missing early values for {station}")))?;
        let late_values = late
            .get(&station)
            .ok_or_else(|| CsvProfError::Message(format!("missing late values for {station}")))?;

        let early_median = median(early_values.clone())?;
        let late_median = median(late_values.clone())?;

        changes.push(StationChange {
            station,
            early_samples: early_values.len(),
            late_samples: late_values.len(),
            early_median,
            late_median,
            delta: late_median - early_median,
        });
    }

    changes.sort_by(|left, right| left.delta.total_cmp(&right.delta));
    Ok(changes)
}

fn median(mut values: Vec<f64>) -> Result<f64, CsvProfError> {
    if values.is_empty() {
        return Err(CsvProfError::Message(
            "cannot compute a median from an empty set of values".to_string(),
        ));
    }

    values.sort_by(|left, right| left.total_cmp(right));
    let middle = values.len() / 2;

    if values.len() % 2 == 0 {
        Ok((values[middle - 1] + values[middle]) / 2.0)
    } else {
        Ok(values[middle])
    }
}

fn column_index(headers: &StringRecord, target: &str) -> Result<usize, CsvProfError> {
    headers
        .iter()
        .position(|header| header == target)
        .ok_or_else(|| CsvProfError::Message(format!("missing required column '{target}'")))
}

fn render_profile_report(title: &str, summaries: &[ColumnSummary]) -> String {
    let mut output = String::new();
    output.push_str(title);
    output.push('\n');
    output.push_str(&"=".repeat(title.len()));
    output.push_str("\n\n");

    for summary in summaries {
        output.push_str("Column: ");
        output.push_str(&summary.header);
        output.push('\n');
        output.push_str(&summary.report);
        output.push_str("\n----------------------------------\n");
    }

    output
}
