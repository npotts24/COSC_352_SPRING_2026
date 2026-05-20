// Declares modules
mod profiler;
mod stats;
mod types;

// Imports parser and CsvProfiler into the code
use clap::Parser;
use profiler::CsvProfiler;
use std::collections::HashMap;

// Defines the argumets used for the code
struct Cli{
    crimes: String,
    neighborhood: char,
}

struct NeighborhoodStats{
    name: String,
    crimes: u32,
    area: f64,
}

cargo run -- --crimes data/GroupA_Crime_Data_.csv --neighborhoods data/Neighborhoods.csv
// Function to read the file and run the profiler
fn main() -> anyhow::Result<()> {
    let args = Cli::parse();
    let crimes = CsvProfiler::load("data/GroupA_Crime_Data_.csv")?;
    let neighborhood = CsvProfiler::load("data/Neighborhoods.csv")?;
    let mut area_map: HashMap<String, f64> = HashMap::new();

    for row in neighborhoods {
        if let (Some(name), Some(area)) = (row.get("Name"), row.get("Shape_Area")) {
        let parsed = area.parse::<f64>().unwrap_or(0.0);
        area_map.insert(name.clone(), parsed);
      }
    }

    let mut total_crime: HashMap<String, u32> = HashMap::new();

    for row in crimes {
        if let Some(n) = row.get("Neighborhood") {
            let key = n.trim().to_string();
            if !key.is_empty() {
                *total_crime.entry(key).or_insert(0) += 1
                }
            }
        }

        let mut joined: Vec <NeighborhoodStats> = Vec::new();

        for (name, crimes) in total_crime {
            if let Some(area) = area_map.get(&name) {
                joined.push(NeighborhoodStats{
                    name,
                    crimes,
                    area: *area,
                });
            }
        }

        joined.sort_by(|a, b| b.crimes.cmp(&a.crimes));
        println!("10 Most Dangerous Neighborhoods Using Crime Count:\n");
        for nc in joined.iter().take(10) {
            println!("{} — {} crimes — area{:.2}", nc.name, nc.crimes, nc.area);
        }

    Ok(())
}