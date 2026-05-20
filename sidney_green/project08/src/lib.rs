use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fs::File;


#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct ColumnProfile {
    pub name: String,
    pub total_count: usize,
    pub null_count: usize,
    pub unique_values: HashSet<String>,
}
pub trait DataProfiler{
    fn profile_csv(path: &str) -> Result<(usize, Vec<ColumnProfile>), Box<dyn Error>>;
}
    


pub struct BaltimoreData;

impl DataProfiler for BaltimoreData {
    fn profile_csv(path: &str) -> Result<(usize, Vec<ColumnProfile>), Box<dyn Error>> {
        let file = File::open(path)?;
        let mut rdr = csv::ReaderBuilder::new().has_headers(true).from_reader(file);
        let headers = rdr.headers()?.clone();

        let mut col_profiles: Vec<ColumnProfile> = headers.iter()
            .map(|h| ColumnProfile { name: h.to_string(), ..Default::default() })
            .collect();

        let mut total_rows = 0;
        for result in rdr.records() {
            let record = result?;
            total_rows += 1;
            for (i, field) in record.iter().enumerate() {
                let profile = &mut col_profiles[i];
                profile.total_count += 1; // Updated for Project 8 requirements
                if field.trim().is_empty() { profile.null_count += 1; }
                profile.unique_values.insert(field.to_string());
            }
        }
        Ok((total_rows, col_profiles))
    }
}


pub fn count_by_district(path: &str, col_name: &str) -> Result<HashMap<String, usize>, Box<dyn Error>> {
    let mut rdr = csv::Reader::from_path(path)?;
    let headers = rdr.headers()?.clone();
    
    
    let idx = headers.iter()
        .position(|h| h.to_uppercase() == col_name.to_uppercase())
        .ok_or("District column not found")?;

    let mut counts = HashMap::new();
    for result in rdr.records() {
        let rec = result?;
        let val = rec.get(idx).unwrap_or("Unknown").trim().to_uppercase();
        if !val.is_empty() {
            *counts.entry(val).or_insert(0) += 1;
        }
    }
    Ok(counts)
}