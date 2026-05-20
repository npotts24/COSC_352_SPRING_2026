use anyhow::Result;
use csv::ReaderBuilder;
use csvprof::{create_profiler, profile_csv_content, read_input, InferredType, CsvProfError, ProfileConfig};
use serde_json;
use std::collections::HashMap;
use std::fs::File;
use std::io::Write;
use std::path::Path;

fn main() -> Result<()> {
    let data_dir = Path::new("data");
    let reports_dir = Path::new("reports");

    let vac_file = data_dir.join("vacant_lots_per_neighborhood.csv");
    let req_file = data_dir.join("311_requests_2024.csv");

    let profile_config = ProfileConfig {
        delimiter: b',',
        no_header: false,
        max_unique: 50,
        percentiles: false,
        top_n: 5,
        hist: false,
    };

    let vac_profile = generate_profile(&vac_file, &profile_config)?;
    let req_profile = generate_profile(&req_file, &profile_config)?;

    write_report(&reports_dir.join("vacant_lots_profile.txt"), &vac_profile)?;
    write_report(&reports_dir.join("311_requests_profile.txt"), &req_profile)?;

    let vacant_by_neighborhood = load_vacant_lots(&vac_file)?;
    let requests_by_neighborhood = load_311_counts(&req_file)?;

    let joined = join_neighborhoods(&vacant_by_neighborhood, &requests_by_neighborhood);
    let correlation = compute_correlation(&joined);

    println!("=== Baltimore Part 2 Analysis ===");
    println!("Neighborhoods joined: {}", joined.len());
    println!("Pearson correlation between vacant lots and 311 requests: {:.4}", correlation);
    println!("\nTop 10 neighborhoods by request-to-vacant-lot ratio:");
    for (name, vacant, requests, ratio) in top_ratio(&joined, 10) {
        println!("- {}: {} vacant lots, {} requests, ratio {:.2}", name, vacant, requests, ratio);
    }

    profile_join_counts(&joined);

    Ok(())
}

fn normalize_name(name: &str) -> String {
    name.to_lowercase()
        .chars()
        .filter(|c| c.is_alphanumeric())
        .collect()
}

fn generate_profile(path: &Path, config: &ProfileConfig) -> Result<String, CsvProfError> {
    let content = read_input(path.to_str().unwrap())?;
    let report = profile_csv_content(&content, path.to_string_lossy().to_string(), config)?;
    Ok(format!("{}\n", serde_json::to_string_pretty(&report).unwrap()))
}

fn write_report(path: &Path, report: &str) -> Result<()> {
    let mut f = File::create(path)?;
    f.write_all(report.as_bytes())?;
    Ok(())
}

fn load_vacant_lots(path: &Path) -> Result<HashMap<String, (String, f64)>, CsvProfError> {
    let mut reader = ReaderBuilder::new().has_headers(true).from_path(path)?;
    let mut map = HashMap::new();

    for result in reader.records() {
        let record = result?;
        let name = record.get(4).unwrap_or("").trim().to_string();
        let value = record
            .get(0)
            .unwrap_or("0")
            .parse::<f64>()
            .unwrap_or(0.0);
        if !name.is_empty() {
            let normalized = normalize_name(&name);
            map.insert(normalized, (name, value));
        }
    }

    Ok(map)
}

fn load_311_counts(path: &Path) -> Result<HashMap<String, f64>, CsvProfError> {
    let mut reader = ReaderBuilder::new().has_headers(true).from_path(path)?;
    let mut map = HashMap::new();

    for result in reader.records() {
        let record = result?;
        let name = record.get(17).unwrap_or("").trim();
        if name.is_empty() {
            continue;
        }
        let normalized = normalize_name(name);
        *map.entry(normalized).or_insert(0.0) += 1.0;
    }
    Ok(map)
}

fn join_neighborhoods(
    vacant: &HashMap<String, (String, f64)>,
    requests: &HashMap<String, f64>,
) -> Vec<(String, f64, f64)> {
    let mut joined = Vec::new();
    for (normalized, (name, vac_cnt)) in vacant {
        let req_cnt = *requests.get(normalized).unwrap_or(&0.0);
        joined.push((name.clone(), *vac_cnt, req_cnt));
    }
    joined.sort_by(|a, b| b.2.partial_cmp(&a.2).unwrap());
    joined
}

fn compute_correlation(data: &[(String, f64, f64)]) -> f64 {
    let n = data.len() as f64;
    if n < 2.0 {
        return 0.0;
    }

    let sum_x: f64 = data.iter().map(|(_, x, _)| *x).sum();
    let sum_y: f64 = data.iter().map(|(_, _, y)| *y).sum();
    let sum_xy: f64 = data.iter().map(|(_, x, y)| x * y).sum();
    let sum_x2: f64 = data.iter().map(|(_, x, _)| x * x).sum();
    let sum_y2: f64 = data.iter().map(|(_, _, y)| y * y).sum();

    let numerator = n * sum_xy - sum_x * sum_y;
    let denominator = ((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y)).sqrt();
    if denominator == 0.0 {
        0.0
    } else {
        numerator / denominator
    }
}

fn top_ratio(data: &[(String, f64, f64)], limit: usize) -> Vec<(String, f64, f64, f64)> {
    let mut rows = data
        .iter()
        .map(|(name, vacant, requests)| {
            let ratio = if *vacant > 0.0 { *requests / *vacant } else { 0.0 };
            (name.clone(), *vacant, *requests, ratio)
        })
        .collect::<Vec<_>>();
    rows.sort_by(|a, b| b.3.partial_cmp(&a.3).unwrap());
    rows.into_iter().take(limit).collect()
}

fn profile_join_counts(data: &[(String, f64, f64)]) {
    let mut profiler = create_profiler(
        "311_requests_per_neighborhood".to_string(),
        InferredType::Integer,
        false,
        5,
        false,
    );
    for (_, _, requests) in data {
        profiler.feed(Some(&requests.to_string()));
    }
    let report = profiler.report();
    println!(
        "\nJoin summary: {} neighborhoods, {} null values",
        report.row_count, report.null_count
    );
    if let Some(stats) = report.numeric_stats {
        println!(
            "Join summary mean requests: {:.2}, min: {:.0}, max: {:.0}",
            stats.mean,
            stats.min,
            stats.max
        );
    }
}
