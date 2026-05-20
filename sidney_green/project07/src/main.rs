use std::env;
use std::error::Error;
use std::fs::File;
use csv::ReaderBuilder;
use serde::Serialize;

#[derive(Serialize, Default, Debug)]
struct ColumnProfile {
    name: String,
    total_count: usize,
    null_count: usize,
    unique_values: std::collections::HashSet<String>,
}

#[derive(Serialize, Debug)]
struct ProfileReport {
    file_name: String,
    total_rows: usize,
    columns: Vec<ColumnProfile>,
}

fn main() -> Result<(), Box<dyn Error>> {
    // 1. Ownership & CLI Args
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: cargo run -- <file.csv>");
        std::process::exit(1);
    }

    let file_path = &args[1];
    let file = File::open(file_path)?;

    let mut rdr = ReaderBuilder::new()
        .has_headers(true)
        .from_reader(file);

    let headers = rdr.headers()?.clone();

    let mut col_profiles: Vec<ColumnProfile> = headers
        .iter()
        .map(|h| ColumnProfile {
            name: h.to_string(),
            ..Default::default()
        })
        .collect();

    let mut total_rows = 0;

    for result in rdr.records() {
        let record = result?;
        total_rows += 1;

        for (i, field) in record.iter().enumerate() {
            let profile = &mut col_profiles[i];
            profile.total_count += 1;
            
            if field.trim().is_empty() {
                profile.null_count += 1;
            }

            profile.unique_values.insert(field.to_string());
        }
    }

    let report = ProfileReport {
        file_name: file_path.to_string(),
        total_rows,
        columns: col_profiles,
    };

    println!("{}", serde_json::to_string_pretty(&report)?);

    Ok(())
}

    