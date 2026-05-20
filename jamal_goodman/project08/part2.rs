use std::collections::HashMap;
use crate::csv_reader::CsvReader;

#[derive(Default)]
struct DistrictStats {
    calls: u32,
    crimes: u32,
}

pub fn run_analysis(calls_path: &str, crimes_path: &str) {
    let mut stats: HashMap<String, DistrictStats> = HashMap::new();

    // -------- CALLS --------
    let mut calls_reader = CsvReader::new(calls_path).expect("calls read failed");
    let headers = calls_reader.headers().clone();

    let district_idx = headers.iter()
        .position(|h| h.to_lowercase() == "district")
        .expect("missing district");

    while let Some(row) = calls_reader.next_row() {
        let district = row[district_idx].trim().to_string();
        if !district.is_empty() {
            stats.entry(district).or_default().calls += 1;
        }
    }

    // -------- CRIMES --------
    let mut crime_reader = CsvReader::new(crimes_path).expect("crime read failed");
    let headers = crime_reader.headers().clone();

    let district_idx = headers.iter()
        .position(|h| h.to_lowercase() == "district")
        .expect("missing district");

    while let Some(row) = crime_reader.next_row() {
        let district = row[district_idx].trim().to_string();
        if !district.is_empty() {
            stats.entry(district).or_default().crimes += 1;
        }
    }

    // -------- OUTPUT --------
    println!("District | Calls | Crimes | Crimes per 1000 Calls");

    for (district, s) in stats.iter() {
        let ratio = if s.calls > 0 {
            (s.crimes as f64 / s.calls as f64) * 1000.0
        } else {
            0.0
        };

        println!(
            "{} | {} | {} | {:.2}",
            district, s.calls, s.crimes, ratio
        );
    }
}