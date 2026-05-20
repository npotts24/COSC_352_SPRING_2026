use csv::ReaderBuilder;
use indexmap::IndexMap;
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufReader, Read};
use std::path::Path;

trait ColumnAnalyzer {
    fn feed(&mut self, val: &str);
    fn count(&self) -> u64;
    fn null_count(&self) -> u64;
}

struct CategoryCounter {
    counts: HashMap<String, u64>,
    total: u64,
    nulls: u64,
}

impl CategoryCounter {
    fn new() -> Self {
        CategoryCounter { counts: HashMap::new(), total: 0, nulls: 0 }
    }

    fn top_n(&self, n: usize) -> Vec<(String, u64)> {
        let mut v: Vec<(String, u64)> = self.counts.iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        v.sort_by(|a, b| b.1.cmp(&a.1));
        v.truncate(n);
        v
    }
}

impl ColumnAnalyzer for CategoryCounter {
    fn feed(&mut self, val: &str) {
        self.total += 1;
        let trimmed = val.trim();
        if trimmed.is_empty() {
            self.nulls += 1;
        } else {
            *self.counts.entry(trimmed.to_string()).or_insert(0) += 1;
        }
    }
    fn count(&self) -> u64 { self.total }
    fn null_count(&self) -> u64 { self.nulls }
}

fn open_csv(path: &Path) -> Result<Box<dyn Read>, std::io::Error> {
    Ok(Box::new(BufReader::new(File::open(path)?)))
}

fn find_col(headers: &csv::StringRecord, name: &str) -> Option<usize> {
    headers.iter().position(|h| h.trim().to_lowercase() == name.to_lowercase())
}

#[derive(Default)]
struct NeighborhoodStats {
    permit_count: u64,
    vacant_count: u64,
    total_cost: u64,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let permit_path = Path::new("data/building_permits.csv");
    let vacant_path = Path::new("data/vacant_buildings.csv");

    println!("=== Reading building permits ===");
    let mut permit_neighborhood = CategoryCounter::new();
    let mut permit_cost_by_neighborhood: HashMap<String, u64> = HashMap::new();

    {
        let reader = open_csv(permit_path)?;
        let mut rdr = ReaderBuilder::new().flexible(true).from_reader(reader);
        let headers = rdr.headers()?.clone();
        let neighborhood_idx = find_col(&headers, "Neighborhood").expect("Neighborhood column not found");
        let cost_idx         = find_col(&headers, "Cost").expect("Cost column not found");
        let modification_idx = find_col(&headers, "IsPermitModification").expect("IsPermitModification column not found");

        for result in rdr.records() {
            let rec = result?;
            if rec.get(modification_idx).unwrap_or("0").trim() == "1" { continue; }

            let neighborhood = rec.get(neighborhood_idx).unwrap_or("").trim().to_string();
            permit_neighborhood.feed(&neighborhood);

            if let Ok(cost) = rec.get(cost_idx).unwrap_or("").trim().parse::<u64>() {
                *permit_cost_by_neighborhood.entry(neighborhood).or_insert(0) += cost;
            }
        }
    }

    println!("  Total original permits : {}", permit_neighborhood.count());
    println!("  Top 5 neighborhoods by permit count:");
    for (k, v) in permit_neighborhood.top_n(5) {
        println!("    {:<35} {}", k, v);
    }
    println!();

    println!("=== Reading vacant buildings ===");
    let mut vacant_neighborhood = CategoryCounter::new();

    {
        let reader = open_csv(vacant_path)?;
        let mut rdr = ReaderBuilder::new().flexible(true).from_reader(reader);
        let headers = rdr.headers()?.clone();
        let neighborhood_idx = find_col(&headers, "Neighborhood").expect("Neighborhood column not found");

        for result in rdr.records() {
            let rec = result?;
            let neighborhood = rec.get(neighborhood_idx).unwrap_or("").trim().to_string();
            vacant_neighborhood.feed(&neighborhood);
        }
    }

    println!("  Total vacant notices : {}", vacant_neighborhood.count());
    println!("  Top 5 neighborhoods by vacant count:");
    for (k, v) in vacant_neighborhood.top_n(5) {
        println!("    {:<35} {}", k, v);
    }
    println!();

    println!("=== Neighborhood Join: Permits vs Vacant Buildings ===");
    let mut by_neighborhood: IndexMap<String, NeighborhoodStats> = IndexMap::new();

    for (neighborhood, count) in &permit_neighborhood.counts {
        by_neighborhood.entry(neighborhood.clone()).or_default().permit_count += count;
    }
    for (neighborhood, count) in &vacant_neighborhood.counts {
        by_neighborhood.entry(neighborhood.clone()).or_default().vacant_count += count;
    }
    for (neighborhood, cost) in &permit_cost_by_neighborhood {
        if let Some(s) = by_neighborhood.get_mut(neighborhood) {
            s.total_cost += cost;
        }
    }

    let mut rows: Vec<(&String, &NeighborhoodStats)> = by_neighborhood.iter().collect();
    rows.sort_by(|a, b| b.1.vacant_count.cmp(&a.1.vacant_count));

    println!("{:<35} {:>10} {:>10} {:>15}", "Neighborhood", "Permits", "Vacants", "Total Cost ($)");
    println!("{}", "-".repeat(72));

    let mut permit_vals: Vec<f64> = Vec::new();
    let mut vacant_vals: Vec<f64> = Vec::new();

    for (neighborhood, stats) in &rows {
        println!("{:<35} {:>10} {:>10} {:>15}",
            neighborhood, stats.permit_count, stats.vacant_count, stats.total_cost);
        if stats.permit_count > 0 && stats.vacant_count > 0 {
            permit_vals.push(stats.permit_count as f64);
            vacant_vals.push(stats.vacant_count as f64);
        }
    }

    let r = pearson(&permit_vals, &vacant_vals);
    println!();
    println!("Pearson r (permits vs vacants, by neighborhood): {:.4}", r);
    println!();
    println!("=== Key Findings ===");

    if let Some((n, s)) = rows.first() {
        println!("  Most vacant neighborhood   : {} ({} vacants, {} permits)", n, s.vacant_count, s.permit_count);
    }
    if let Some((n, s)) = rows.iter().max_by_key(|(_, s)| s.permit_count) {
        println!("  Most permitted neighborhood: {} ({} permits, {} vacants)", n, s.permit_count, s.vacant_count);
    }

    Ok(())
}

fn pearson(x: &[f64], y: &[f64]) -> f64 {
    if x.len() != y.len() || x.len() < 2 { return f64::NAN; }
    let n  = x.len() as f64;
    let mx = x.iter().sum::<f64>() / n;
    let my = y.iter().sum::<f64>() / n;
    let num: f64 = x.iter().zip(y).map(|(xi, yi)| (xi - mx) * (yi - my)).sum();
    let dx: f64  = x.iter().map(|xi| (xi - mx).powi(2)).sum::<f64>().sqrt();
    let dy: f64  = y.iter().map(|yi| (yi - my).powi(2)).sum::<f64>().sqrt();
    if dx == 0.0 || dy == 0.0 { return f64::NAN; }
    num / (dx * dy)
}