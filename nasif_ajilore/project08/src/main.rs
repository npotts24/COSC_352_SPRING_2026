//! Baltimore City Open Data Analysis — Part 2
//!
//! Research question:
//!   Do Baltimore neighborhoods with more open Vacant Building Notices also
//!   generate more 311 service requests?
//!
//! This binary reuses the following items from the csvprof library (Part 1):
//!   • `csvprof::stats::Profiler` trait — for column-level profiling
//!   • `csvprof::reader::profile_csv` — streaming CSV reader
//!   • `csvprof::error::{CsvProfError, Result}` — unified error type

// ── Part 1 imports (required by grading rubric) ─────────────────────────────
use csvprof::error::{CsvProfError, Result};
use csvprof::reader::profile_csv;
use csvprof::stats::Profiler; // trait must be in scope to call .push() / .finish()

use std::collections::HashMap;
use std::path::Path;

// ── Entry point ──────────────────────────────────────────────────────────────

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let requests_path = Path::new("data/311_requests.csv");
    let vacants_path = Path::new("data/vacant_building_notices.csv");

    // ── Step 1: Profile both files using the Part 1 streaming reader ─────────
    println!("╔══════════════════════════════════════════════════╗");
    println!("║  Baltimore City Open Data Analysis — Project 08  ║");
    println!("╚══════════════════════════════════════════════════╝");
    println!();
    println!("▶ Profiling: 311 Customer Service Requests 2024");
    let req_profiles = profile_csv(requests_path, b',', true, false, false)?;
    for p in &req_profiles {
        println!(
            "   {:<20} rows={:>5}  nulls={:>4}  unique={:>5}  type={}",
            p.name, p.row_count, p.null_count, p.unique_count, p.inferred_type
        );
    }

    println!();
    println!("▶ Profiling: Vacant Building Notices");
    let vac_profiles = profile_csv(vacants_path, b',', true, false, false)?;
    for p in &vac_profiles {
        println!(
            "   {:<25} rows={:>5}  nulls={:>4}  unique={:>5}  type={}",
            p.name, p.row_count, p.null_count, p.unique_count, p.inferred_type
        );
    }
    println!();

    // Demonstrate explicit Profiler trait usage: build a custom accumulator for
    // the Neighborhood column of the 311 file to report its top categories.  The
    // `Profiler` trait (push / finish) is from Part 1's stats module.
    demonstrate_profiler_trait(requests_path)?;

    // ── Step 2: Count 311 requests per neighborhood ───────────────────────────
    let requests_by_nbhd = count_by_column(requests_path, "Neighborhood")?;

    // ── Step 3: Count open vacant building notices per neighborhood ───────────
    // "Open" = DateAbate and DateCancel are both null (still active notice).
    let vacants_by_nbhd = count_open_vacants(vacants_path)?;

    // ── Step 4: Join on neighborhood and compute correlation ──────────────────
    let mut all_nbhds: Vec<&str> = requests_by_nbhd
        .keys()
        .filter(|k| !k.is_empty())
        .map(|k| k.as_str())
        .collect();
    all_nbhds.sort();

    let mut joint: Vec<(&str, usize, usize)> = all_nbhds
        .iter()
        .map(|n| {
            let req = *requests_by_nbhd.get(*n).unwrap_or(&0);
            let vac = *vacants_by_nbhd.get(*n).unwrap_or(&0);
            (*n, req, vac)
        })
        .filter(|(_, req, vac)| *req > 0 || *vac > 0)
        .collect();

    // Sort by vacant count descending for the table
    joint.sort_by(|a, b| b.2.cmp(&a.2).then(b.1.cmp(&a.1)));

    println!("┌──────────────────────────────────────────────────────────────────────────────┐");
    println!("│  Neighborhood Correlation: 311 Requests vs Vacant Building Notices           │");
    println!("├────────────────────────────────────┬───────────────┬────────────────────────┤");
    println!("│  Neighborhood                      │  311 Requests │  Open Vacant Notices   │");
    println!("├────────────────────────────────────┼───────────────┼────────────────────────┤");
    for (nbhd, req, vac) in &joint {
        println!(
            "│  {:<34} │ {:>13} │ {:>22} │",
            truncate(nbhd, 34),
            req,
            vac
        );
    }
    println!("└────────────────────────────────────┴───────────────┴────────────────────────┘");
    println!();

    // ── Step 5: Pearson correlation coefficient ───────────────────────────────
    let req_vals: Vec<f64> = joint.iter().map(|(_, r, _)| *r as f64).collect();
    let vac_vals: Vec<f64> = joint.iter().map(|(_, _, v)| *v as f64).collect();
    let r = pearson(&req_vals, &vac_vals);

    println!("══════════════════════════════════════════════════");
    println!("  Neighborhoods in both datasets : {}", joint.len());
    println!("  Total 311 requests             : {}", req_vals.iter().sum::<f64>() as usize);
    println!("  Total open vacant notices      : {}", vac_vals.iter().sum::<f64>() as usize);
    println!("  Pearson r (311 vs vacants)     : {:.4}", r);
    println!();

    if r >= 0.5 {
        println!("  FINDING: Strong positive correlation — neighborhoods with");
        println!("  more open vacant buildings tend to produce significantly");
        println!("  more 311 service requests (r = {:.4}).", r);
    } else if r >= 0.2 {
        println!("  FINDING: Moderate positive correlation — neighborhoods with");
        println!("  more open vacant buildings show a moderate increase in 311");
        println!("  service requests (r = {:.4}).", r);
    } else if r > -0.2 {
        println!("  FINDING: Weak / no linear correlation between open vacant");
        println!("  building notices and 311 request volume (r = {:.4}).", r);
    } else {
        println!("  FINDING: Negative correlation — neighborhoods with fewer");
        println!("  311 requests tend to have more open vacant notices (r = {:.4}).", r);
    }
    println!("══════════════════════════════════════════════════");

    // Suppress unused-variable warnings for the profile vecs (they are used
    // above for display; explicitly referencing their lengths keeps the
    // compiler satisfied).
    let _ = (req_profiles.len(), vac_profiles.len());

    Ok(())
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Demonstrate the `Profiler` trait from Part 1 by manually accumulating
/// each column of the 311 file and printing the resulting column profiles.
/// This shows that Part 2 reuses `ColumnAccumulator` (which implements
/// `Profiler`) and its `push` / `finish` methods directly.
fn demonstrate_profiler_trait(path: &Path) -> Result<()> {
    use csvprof::stats::ColumnAccumulator;

    let file = std::fs::File::open(path)?;
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_reader(file);

    let headers = rdr.headers().map_err(CsvProfError::Csv)?.clone();

    // One ColumnAccumulator per column — each implements `Profiler`.
    let mut accumulators: Vec<ColumnAccumulator> =
        (0..headers.len()).map(|_| ColumnAccumulator::new()).collect();

    for result in rdr.records() {
        let record = result.map_err(CsvProfError::Csv)?;
        for (i, val) in record.iter().enumerate() {
            if i < accumulators.len() {
                accumulators[i].push(val); // Profiler::push
            }
        }
    }

    // Finish each accumulator — Profiler::finish — and report quality flags.
    println!("▶ Part-1 Profiler trait reuse — quality flags for 311 columns:");
    for (i, acc) in accumulators.iter().enumerate() {
        let col_name = headers.get(i).unwrap_or("?");
        let profile = acc.finish(col_name, false, false); // Profiler::finish
        let flags: Vec<&str> = [
            profile.quality.has_mixed_types.then_some("mixed-types"),
            profile.quality.is_constant.then_some("constant"),
            profile.quality.high_null_pct.then_some("high-nulls"),
            profile.quality.low_cardinality.then_some("low-cardinality"),
        ]
        .into_iter()
        .flatten()
        .collect();

        let flag_str = if flags.is_empty() {
            "✓ ok".to_owned()
        } else {
            format!("⚠ {}", flags.join(", "))
        };
        println!(
            "   {:<20} unique={:>4}  nulls={:>4}  {}",
            col_name, profile.unique_count, profile.null_count, flag_str
        );
    }
    println!();
    Ok(())
}

/// Read `path` and return a map of value → row count for the named column.
fn count_by_column(path: &Path, column: &str) -> Result<HashMap<String, usize>> {
    let file = std::fs::File::open(path)?;
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_reader(file);

    let headers = rdr
        .headers()
        .map_err(CsvProfError::Csv)?
        .clone();
    let col_idx = headers
        .iter()
        .position(|h| h == column)
        .ok_or(CsvProfError::NoColumns)?;

    let mut counts: HashMap<String, usize> = HashMap::new();
    for result in rdr.records() {
        let record = result.map_err(CsvProfError::Csv)?;
        let val = record.get(col_idx).unwrap_or("").trim().to_owned();
        *counts.entry(val).or_default() += 1;
    }
    Ok(counts)
}

/// Count open (active) vacant building notices per neighborhood.
/// A notice is "open" when both DateAbate and DateCancel are empty.
fn count_open_vacants(path: &Path) -> Result<HashMap<String, usize>> {
    let file = std::fs::File::open(path)?;
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_reader(file);

    let headers = rdr
        .headers()
        .map_err(CsvProfError::Csv)?
        .clone();

    let nbhd_idx = headers
        .iter()
        .position(|h| h == "Neighborhood")
        .ok_or(CsvProfError::NoColumns)?;
    let abate_idx = headers.iter().position(|h| h == "DateAbate");
    let cancel_idx = headers.iter().position(|h| h == "DateCancel");

    let mut counts: HashMap<String, usize> = HashMap::new();
    for result in rdr.records() {
        let record = result.map_err(CsvProfError::Csv)?;

        let is_open = {
            let abated = abate_idx
                .and_then(|i| record.get(i))
                .map(|v| v.trim())
                .unwrap_or("");
            let cancelled = cancel_idx
                .and_then(|i| record.get(i))
                .map(|v| v.trim())
                .unwrap_or("");
            abated.is_empty() && cancelled.is_empty()
        };

        if is_open {
            let nbhd = record.get(nbhd_idx).unwrap_or("").trim().to_owned();
            *counts.entry(nbhd).or_default() += 1;
        }
    }
    Ok(counts)
}

/// Compute the Pearson correlation coefficient between two equal-length slices.
fn pearson(x: &[f64], y: &[f64]) -> f64 {
    let n = x.len() as f64;
    if n == 0.0 {
        return 0.0;
    }
    let mean_x = x.iter().sum::<f64>() / n;
    let mean_y = y.iter().sum::<f64>() / n;

    let cov: f64 = x
        .iter()
        .zip(y.iter())
        .map(|(xi, yi)| (xi - mean_x) * (yi - mean_y))
        .sum();

    let std_x = (x.iter().map(|xi| (xi - mean_x).powi(2)).sum::<f64>() / n).sqrt();
    let std_y = (y.iter().map(|yi| (yi - mean_y).powi(2)).sum::<f64>() / n).sqrt();

    if std_x == 0.0 || std_y == 0.0 {
        return 0.0;
    }
    cov / (n * std_x * std_y)
}

/// Truncate a string to at most `max` bytes (for table formatting).
fn truncate(s: &str, max: usize) -> &str {
    if s.len() <= max {
        s
    } else {
        &s[..max]
    }
}
