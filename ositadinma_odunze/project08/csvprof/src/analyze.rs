//! Part 2 — Baltimore City Open Data Correlator
//!
//! Research question:
//!   Do Baltimore ZIP codes with more active liquor licenses have a higher
//!   concentration of registered gun offenders?
//!
//! Datasets:
//!   - Gun Offenders Registry (data.baltimorecity.gov)
//!   - Liquor Licenses (data.baltimorecity.gov)
//!
//! Join key: ZipCode (gun offenders) ↔ AddrZip (liquor licenses)
//!
//! Part 1 code reused:
//!   - `ColumnAccumulator` + `AccumulatorConfig` — streaming column profiling
//!   - `InferredType`                            — type-safe column classification
//!   - `Profiler` trait                          — column-level abstraction
//!   - `CsvProfError` via anyhow                 — structured error handling

mod accumulator;
mod cli;
mod error;
mod infer;
mod profiler;
mod report;
mod types;

use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

use anyhow::{Context, Result};

use crate::accumulator::{AccumulatorConfig, ColumnAccumulator};
use crate::types::InferredType;

// ── shared config for Part 1 profiling ───────────────────────────────────────
fn profiling_cfg() -> AccumulatorConfig {
    AccumulatorConfig {
        categorical_threshold: 50,
        max_categories:        1000,
        compute_percentiles:   false,
        emit_histogram:        false,
    }
}

// ── stream a CSV, run Part 1 column profiling, return (headers, rows) ────────
fn load_and_profile(path: &str) -> Result<(Vec<String>, Vec<Vec<String>>)> {
    let file = File::open(path).with_context(|| format!("Cannot open '{}'", path))?;
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .flexible(true)
        .trim(csv::Trim::All)
        .from_reader(BufReader::new(file));

    // strip BOM if present
    let raw_headers = rdr.headers()?.clone();
    let headers: Vec<String> = raw_headers
        .iter()
        .map(|h| h.trim_start_matches('\u{feff}').trim().to_owned())
        .collect();

    let ncols = headers.len();
    let cfg = profiling_cfg();

    // ── Part 1 reuse: one ColumnAccumulator per column ────────────────────
    let mut accs: Vec<ColumnAccumulator> = headers
        .iter()
        .map(|h| ColumnAccumulator::new(h, cfg.max_categories))
        .collect();

    let mut rows: Vec<Vec<String>> = Vec::new();
    let mut record = csv::StringRecord::new();

    while rdr.read_record(&mut record)? {
        let row: Vec<String> = (0..ncols)
            .map(|i| record.get(i).unwrap_or("").trim().to_owned())
            .collect();
        for (i, acc) in accs.iter_mut().enumerate() {
            let v = row.get(i).map(|s| s.as_str()).filter(|s| !s.is_empty());
            acc.feed(v);
        }
        rows.push(row);
    }

    // ── print inferred-type summary (Part 1 InferredType in action) ───────
    println!("  {} — {} rows × {} columns", path, rows.len(), ncols);
    let profiles: Vec<_> = accs.into_iter().map(|a| a.finalize(&cfg)).collect();
    for p in &profiles {
        // Part 1 reuse: match on InferredType enum
        let t = match p.inferred_type {
            InferredType::Integer     => "integer",
            InferredType::Float       => "float",
            InferredType::Boolean     => "bool",
            InferredType::Date        => "date",
            InferredType::Categorical => "categorical",
            InferredType::Text        => "text",
        };
        let warn = if p.warnings.is_empty() { String::new() }
                   else { format!(" ⚠ {}", p.warnings[0]) };
        println!("    {:30} {:12}  nulls:{:5.1}%{}", p.name, t, p.null_pct, warn);
    }
    println!();

    Ok((headers, rows))
}

fn col(headers: &[String], name: &str) -> Result<usize> {
    headers.iter().position(|h| h.eq_ignore_ascii_case(name))
        .with_context(|| format!("Column '{}' not found. Headers: {:?}", name, headers))
}

// ── per-ZIP aggregates ────────────────────────────────────────────────────────
#[derive(Debug, Default)]
struct ZipStats {
    gun_offenders:   u64,
    active_licenses: u64,
    district:        String,
}

fn main() -> Result<()> {
    println!();
    println!("══════════════════════════════════════════════════════════════════");
    println!("  Baltimore City — Liquor Licenses × Gun Offenders Correlator");
    println!("══════════════════════════════════════════════════════════════════");
    println!();
    println!("Research question:");
    println!("  Do Baltimore ZIP codes with more active liquor licenses have");
    println!("  a higher concentration of registered gun offenders?");
    println!();
    println!("Join key: ZipCode (Gun Offenders) ↔ AddrZip (Liquor Licenses)");
    println!();

    // ── 1. load both datasets using Part 1 streaming + profiling ─────────
    let (gun_h, gun_rows)  = load_and_profile("data/Gun_Offenders.csv")?;
    let (liq_h, liq_rows)  = load_and_profile("data/Liquor_Licenses.csv")?;

    // ── 2. locate needed columns ──────────────────────────────────────────
    let gun_zip_col      = col(&gun_h, "ZipCode")?;
    let gun_dist_col     = col(&gun_h, "District")?;
    let liq_zip_col      = col(&liq_h, "AddrZip")?;
    let liq_status_col   = col(&liq_h, "LicenseStatus")?;

    // ── 3. aggregate by ZIP ───────────────────────────────────────────────
    let mut stats: HashMap<String, ZipStats> = HashMap::new();

    for row in &gun_rows {
        let zip  = row.get(gun_zip_col).map(|s| s.trim().to_owned()).unwrap_or_default();
        let dist = row.get(gun_dist_col).map(|s| s.trim().to_uppercase()).unwrap_or_default();
        if zip.is_empty() { continue; }
        let e = stats.entry(zip).or_default();
        e.gun_offenders += 1;
        if e.district.is_empty() { e.district = dist; }
    }

    for row in &liq_rows {
        let zip    = row.get(liq_zip_col).map(|s| s.trim().to_owned()).unwrap_or_default();
        let status = row.get(liq_status_col).map(|s| s.trim().to_lowercase()).unwrap_or_default();
        if zip.is_empty() { continue; }
        if status == "active" || status == "renewed" {
            stats.entry(zip.clone()).or_default().active_licenses += 1;
        }
    }

    // ── 4. filter to ZIPs present in both datasets ────────────────────────
    let mut table: Vec<(&String, &ZipStats)> = stats
        .iter()
        .filter(|(_, s)| s.gun_offenders > 0 && s.active_licenses > 0)
        .collect();
    table.sort_by(|a, b| b.1.gun_offenders.cmp(&a.1.gun_offenders));

    // ── 5. print results table ────────────────────────────────────────────
    println!("Results — ZIPs present in both datasets ({} ZIPs):", table.len());
    println!();
    println!("┌──────────┬─────────────────────┬──────────────────┬───────────────┐");
    println!("│ ZIP Code │ District            │ Active Licenses  │ Gun Offenders │");
    println!("├──────────┼─────────────────────┼──────────────────┼───────────────┤");
    for (zip, s) in &table {
        println!("│ {:8} │ {:19} │ {:16} │ {:13} │",
            zip, s.district, s.active_licenses, s.gun_offenders);
    }
    println!("└──────────┴─────────────────────┴──────────────────┴───────────────┘");

    // ── 6. Pearson correlation ────────────────────────────────────────────
    let data: Vec<(f64, f64)> = table
        .iter()
        .map(|(_, s)| (s.active_licenses as f64, s.gun_offenders as f64))
        .collect();

    let n      = data.len() as f64;
    let mean_x = data.iter().map(|(x,_)| x).sum::<f64>() / n;
    let mean_y = data.iter().map(|(_,y)| y).sum::<f64>() / n;
    let cov    = data.iter().map(|(x,y)| (x-mean_x)*(y-mean_y)).sum::<f64>() / n;
    let std_x  = (data.iter().map(|(x,_)| (x-mean_x).powi(2)).sum::<f64>() / n).sqrt();
    let std_y  = (data.iter().map(|(_,y)| (y-mean_y).powi(2)).sum::<f64>() / n).sqrt();
    let r      = if std_x * std_y > 0.0 { cov / (std_x * std_y) } else { 0.0 };

    let interpretation = if r > 0.6 {
        "Strong positive — more liquor licenses strongly predicts more gun offenders."
    } else if r > 0.3 {
        "Moderate positive — liquor license density is a partial predictor."
    } else if r > 0.0 {
        "Weak positive — limited relationship at ZIP code level."
    } else if r < -0.3 {
        "Negative correlation — more licenses associated with fewer offenders."
    } else {
        "No meaningful correlation detected."
    };

    println!();
    println!("Pearson r (active licenses vs gun offenders):  r = {:.4}", r);
    println!("Interpretation: {}", interpretation);

    // ── 7. top / bottom highlights ────────────────────────────────────────
    println!();
    println!("Top 3 ZIPs by gun offenders:");
    for (zip, s) in table.iter().take(3) {
        println!("  {} ({}) — {} offenders, {} licenses",
            zip, s.district, s.gun_offenders, s.active_licenses);
    }
    println!("Bottom 3 ZIPs by gun offenders (of matched ZIPs):");
    for (zip, s) in table.iter().rev().take(3) {
        println!("  {} ({}) — {} offenders, {} licenses",
            zip, s.district, s.gun_offenders, s.active_licenses);
    }

    println!();
    println!("Full column profiles available in reports/");
    println!();
    Ok(())
}
