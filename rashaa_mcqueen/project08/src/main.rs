use std::collections::HashMap;
use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    println!("Analyzing datasets...\n");

    let mut crime_counts: HashMap<String, i32> = HashMap::new();
    let mut vacant_counts: HashMap<String, i32> = HashMap::new();

    // -------- READ CRIME DATA --------
    let mut rdr = csv::ReaderBuilder::new()
        .flexible(true)
        .has_headers(true)
        .from_path("data/crime.csv")?;

    let headers = rdr.headers()?.clone();

    let neigh_index = headers
        .iter()
        .position(|h| h.to_lowercase().contains("neighborhood"))
        .unwrap_or(0);

    for result in rdr.records() {
        let record = match result {
            Ok(r) => r,
            Err(_) => continue, // skip bad rows
        };

        let neighborhood = record
            .get(neigh_index)
            .unwrap_or("")
            .trim()
            .to_uppercase();

        if !neighborhood.is_empty() {
            *crime_counts.entry(neighborhood).or_insert(0) += 1;
        }
    }

    // -------- READ VACANT DATA --------
    let mut rdr2 = csv::ReaderBuilder::new()
        .flexible(true)
        .has_headers(true)
        .from_path("data/vacant.csv")?;

    let headers2 = rdr2.headers()?.clone();

    let neigh_index2 = headers2
        .iter()
        .position(|h| {
            let h = h.to_lowercase();
            h.contains("neighborhood") || h.contains("community") || h.contains("area")
        })
        .unwrap_or(0);

    for result in rdr2.records() {
        let record = match result {
            Ok(r) => r,
            Err(_) => continue, // skip bad rows
        };

        let neighborhood = record
            .get(neigh_index2)
            .unwrap_or("")
            .trim()
            .to_uppercase();

        if !neighborhood.is_empty() {
            *vacant_counts.entry(neighborhood).or_insert(0) += 1;
        }
    }

    // -------- JOIN + PRINT --------
    println!("Neighborhood Analysis:\n");

    for (neigh, crime_count) in &crime_counts {
        let vacant_count = vacant_counts.get(neigh).unwrap_or(&0);

        println!(
            "{} → Crimes: {} | Vacant Buildings: {}",
            neigh, crime_count, vacant_count
        );
    }

    Ok(())
}