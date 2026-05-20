//! Part 2: Baltimore City Open Data Analysis
//! Joins Part 1 Crime Data and 311 Service Requests by Neighborhood
//! Reuses types, traits, and reader functions from csvprof (project07).

use csvprof::{ColumnAnalyzer, DefaultColumnAnalyzer, CsvProfError, read_csv_columns};
use std::collections::HashMap;

fn main() -> Result<(), CsvProfError> {
    let crime_path = "data/crime_data.csv";
    let req_path   = "data/requests_311.csv";

    println!("\n=====================================================");
    println!(" Baltimore City: Crime vs 311 Requests by Neighborhood");
    println!("=====================================================");

    // --- Load and profile crime data using Part 1 reader ---
    let (crime_headers, crime_cols) = read_csv_columns(crime_path)?;
    println!("\n[Crime Data] {} columns, {} rows", crime_headers.len(), crime_cols[0].len());
    for (i, header) in crime_headers.iter().enumerate() {
        let mut profile = DefaultColumnAnalyzer::analyze(crime_cols[i].clone());
        profile.name = header.clone();
        println!("  Column '{}': type={:?}, unique={}, nulls={}",
            profile.name, profile.col_type, profile.unique_values, profile.null_count);
    }

    // --- Load and profile 311 data using Part 1 reader ---
    let (req_headers, req_cols) = read_csv_columns(req_path)?;
    println!("\n[311 Service Requests] {} columns, {} rows", req_headers.len(), req_cols[0].len());
    for (i, header) in req_headers.iter().enumerate() {
        let mut profile = DefaultColumnAnalyzer::analyze(req_cols[i].clone());
        profile.name = header.clone();
        println!("  Column '{}': type={:?}, unique={}, nulls={}",
            profile.name, profile.col_type, profile.unique_values, profile.null_count);
    }

    // --- Build neighborhood -> crime_count map ---
    let crime_neighborhood_idx = crime_headers.iter().position(|h| h == "Neighborhood")
        .ok_or_else(|| CsvProfError::MissingColumn("Neighborhood".to_string()))?;
    let crime_count_idx = crime_headers.iter().position(|h| h == "crime_count")
        .ok_or_else(|| CsvProfError::MissingColumn("crime_count".to_string()))?;

    let mut crime_map: HashMap<String, u64> = HashMap::new();
    let row_count = crime_cols[0].len();
    for i in 0..row_count {
        let neighborhood = crime_cols[crime_neighborhood_idx][i].trim().to_uppercase();
        if let Ok(count) = crime_cols[crime_count_idx][i].trim().parse::<u64>() {
            crime_map.insert(neighborhood, count);
        }
    }

    // --- Build neighborhood -> request_count map ---
    let req_neighborhood_idx = req_headers.iter().position(|h| h == "Neighborhood")
        .ok_or_else(|| CsvProfError::MissingColumn("Neighborhood".to_string()))?;
    let req_count_idx = req_headers.iter().position(|h| h == "request_count")
        .ok_or_else(|| CsvProfError::MissingColumn("request_count".to_string()))?;

    let mut req_map: HashMap<String, u64> = HashMap::new();
    let req_row_count = req_cols[0].len();
    for i in 0..req_row_count {
        let neighborhood = req_cols[req_neighborhood_idx][i].trim().to_uppercase();
        if let Ok(count) = req_cols[req_count_idx][i].trim().parse::<u64>() {
            req_map.insert(neighborhood, count);
        }
    }

    // --- Inner join: only neighborhoods present in both datasets ---
    let mut joined: Vec<(String, u64, u64)> = Vec::new();
    for (neighborhood, &crimes) in &crime_map {
        if let Some(&requests) = req_map.get(neighborhood) {
            joined.push((neighborhood.clone(), crimes, requests));
        }
    }

    println!("\n--- Joined on Neighborhood: {} matched neighborhoods ---", joined.len());

    // --- Sort by crime count descending ---
    joined.sort_by(|a, b| b.1.cmp(&a.1));

    // --- Print top 20 neighborhoods ---
    println!("\n{:<45} {:>12} {:>15}", "Neighborhood", "Crime Count", "311 Requests");
    println!("{}", "-".repeat(75));
    for (neighborhood, crimes, requests) in joined.iter().take(20) {
        println!("{:<45} {:>12} {:>15}", neighborhood, crimes, requests);
    }

    // --- Compute Pearson correlation coefficient ---
    let n = joined.len() as f64;
    let crime_vals: Vec<f64> = joined.iter().map(|(_, c, _)| *c as f64).collect();
    let req_vals: Vec<f64>   = joined.iter().map(|(_, _, r)| *r as f64).collect();

    let mean_c = crime_vals.iter().sum::<f64>() / n;
    let mean_r = req_vals.iter().sum::<f64>() / n;

    let numerator: f64 = crime_vals.iter().zip(req_vals.iter())
        .map(|(c, r)| (c - mean_c) * (r - mean_r))
        .sum();
    let denom_c: f64 = crime_vals.iter().map(|c| (c - mean_c).powi(2)).sum::<f64>().sqrt();
    let denom_r: f64 = req_vals.iter().map(|r| (r - mean_r).powi(2)).sum::<f64>().sqrt();

    let pearson = if denom_c * denom_r == 0.0 { 0.0 } else { numerator / (denom_c * denom_r) };

    // --- Tier analysis: split into low/mid/high crime neighborhoods ---
    let mut sorted_by_crime = joined.clone();
    sorted_by_crime.sort_by(|a, b| b.1.cmp(&a.1));
    let third = sorted_by_crime.len() / 3;

    let high_crime: Vec<_> = sorted_by_crime.iter().take(third).collect();
    let low_crime: Vec<_>  = sorted_by_crime.iter().rev().take(third).collect();

    let avg_req_high: f64 = high_crime.iter().map(|(_, _, r)| *r as f64).sum::<f64>() / high_crime.len() as f64;
    let avg_req_low: f64  = low_crime.iter().map(|(_, _, r)| *r as f64).sum::<f64>() / low_crime.len() as f64;

    println!("\n=====================================================");
    println!(" CORRELATION ANALYSIS RESULTS");
    println!("=====================================================");
    println!("  Matched neighborhoods: {}", joined.len());
    println!("  Pearson correlation (crime vs 311 requests): {:.4}", pearson);
    println!("  Avg 311 requests in HIGH-crime neighborhoods:  {:.1}", avg_req_high);
    println!("  Avg 311 requests in LOW-crime neighborhoods:   {:.1}", avg_req_low);
    println!("  Ratio (high/low):                              {:.2}x", avg_req_high / avg_req_low);
    println!("\n  Top 5 highest crime neighborhoods and their 311 request counts:");
    for (name, crimes, reqs) in sorted_by_crime.iter().take(5) {
        println!("    {:<40} crimes={:<8} requests={}", name, crimes, reqs);
    }
    println!("\n  Interpretation:");
    if pearson > 0.5 {
        println!("  Strong positive correlation (r={:.4}): neighborhoods with more", pearson);
        println!("  Part 1 crimes also tend to have more 311 service requests,");
        println!("  suggesting that high-crime areas experience concentrated");
        println!("  infrastructure neglect and resident distress.");
    } else if pearson > 0.2 {
        println!("  Moderate positive correlation (r={:.4}): some association", pearson);
        println!("  exists between crime counts and 311 service requests.");
    } else {
        println!("  Weak correlation (r={:.4}): crime count and 311 request", pearson);
        println!("  volume do not strongly align at the neighborhood level.");
    }
    println!("=====================================================");

    Ok(())
}
