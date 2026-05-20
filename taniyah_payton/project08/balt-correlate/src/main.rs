/// balt-correlate — Project 8
///
/// Joins two Baltimore City open datasets on the `Agency` / `agencyName` column:
///
///   Dataset 1: 311 Customer Service Requests (data.baltimorecity.gov)
///              Columns used: Agency, CreatedDate, CloseDate, SRType, SRStatus
///
///   Dataset 2: Baltimore City Employee Salaries (data.baltimorecity.gov)
///              Columns used: agencyName, grossPay
///
/// Research question:
///   Do city agencies whose employees earn higher average gross pay resolve
///   311 service requests more quickly (fewer days between CreatedDate and CloseDate)?
///
/// Part 1 reuse (csvprof library):
///   - CsvIngestor       — streaming CSV reader; no re-implementation
///   - ProfilerError     — FileNotFound / EmptyFile / Csv variants
///   - is_null           — null-sentinel detection
///   - infer_type        — column type inference (used under --profile)
///   - Profiler trait + DispatchProfiler — column profiling (used under --profile)
///   - ProfilerOptions   — options struct forwarded to DispatchProfiler
///   - report::print_report — human-readable column summary output

use std::{collections::HashMap, fs::File};

use anyhow::Context;
use clap::Parser;
use colored::Colorize;
use comfy_table::{presets::UTF8_FULL, Cell, CellAlignment, Color, ContentArrangement, Table};

// ── Re-use Part 1 ─────────────────────────────────────────────────────────────
use csvprof::{
    error::ProfilerError,
    ingest::CsvIngestor,
    profile::{Profiler, ProfilerOptions},
    profilers::DispatchProfiler,
    types::{infer_type, is_null},
};

// ── CLI ───────────────────────────────────────────────────────────────────────

/// Correlate 311 resolution speed with city-agency salary levels.
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to 311 Service Requests CSV
    #[arg(long, default_value = "data/311_service_requests.csv")]
    requests: String,

    /// Path to Baltimore City Employee Salaries CSV
    #[arg(long, default_value = "data/baltimore_salaries.csv")]
    salaries: String,

    /// Also print csvprof column summaries for both files before correlation
    #[arg(long, short)]
    profile: bool,
}

// ── Domain types ──────────────────────────────────────────────────────────────

struct ServiceRequest {
    agency: String,
    resolution_days: f64,
}

struct Employee {
    agency_name: String,
    gross_pay: f64,
}

#[derive(Debug)]
struct AgencyStats {
    name: String,
    request_count: usize,
    avg_resolution_days: f64,
    employee_count: usize,
    avg_gross_pay: f64,
}

// ── Date helpers ──────────────────────────────────────────────────────────────

/// Parse YYYY-MM-DD into (year, month, day).
fn parse_ymd(s: &str) -> Option<(i32, u32, u32)> {
    let s = s.trim();
    let parts: Vec<&str> = s.split('-').collect();
    if parts.len() != 3 { return None; }
    let y = parts[0].parse::<i32>().ok()?;
    let m = parts[1].parse::<u32>().ok()?;
    let d = parts[2].parse::<u32>().ok()?;
    Some((y, m, d))
}

/// Days between two YYYY-MM-DD dates (close - create). Returns None if unparseable.
fn days_between(created: &str, closed: &str) -> Option<f64> {
    let (y1, m1, d1) = parse_ymd(created)?;
    let (y2, m2, d2) = parse_ymd(closed)?;
    // Simple Julian Day Number difference — no external crate needed.
    let jd = |y: i32, m: u32, d: u32| -> i64 {
        let a = (14 - m as i32) / 12;
        let yr = y + 4800 - a;
        let mo = m as i32 + 12 * a - 3;
        d as i64
            + ((153 * mo + 2) / 5) as i64
            + 365 * yr as i64
            + (yr / 4) as i64
            - (yr / 100) as i64
            + (yr / 400) as i64
            - 32045
    };
    let diff = jd(y2, m2, d2) - jd(y1, m1, d1);
    if diff < 0 { None } else { Some(diff as f64) }
}

// ── Loaders ───────────────────────────────────────────────────────────────────

fn load_requests(path: &str) -> anyhow::Result<Vec<ServiceRequest>> {
    // Use Part 1's CsvIngestor — no re-implementation of CSV reading.
    let f = File::open(path)
        .map_err(|_| ProfilerError::FileNotFound { path: path.to_string() })
        .with_context(|| format!("Cannot open 311 file: {path}"))?;

    let data = CsvIngestor::ingest(f)
        .with_context(|| format!("Failed to parse 311 CSV: {path}"))?;

    let col = |name: &str| -> anyhow::Result<usize> {
        data.headers
            .iter()
            .position(|h| h.eq_ignore_ascii_case(name))
            .with_context(|| format!("Column '{name}' not found in {path}"))
    };

    let agency_idx  = col("Agency")?;
    let created_idx = col("CreatedDate")?;
    let close_idx   = col("CloseDate")?;
    let status_idx  = col("SRStatus")?;

    let n = data.column_values[0].len();
    let mut out = Vec::with_capacity(n);

    for i in 0..n {
        // Only include closed requests so resolution_days is meaningful.
        let status = data.column_values[status_idx][i].trim().to_string();
        if !status.eq_ignore_ascii_case("Closed") {
            continue;
        }

        let agency  = data.column_values[agency_idx][i].trim().to_string();
        let created = &data.column_values[created_idx][i];
        let closed  = &data.column_values[close_idx][i];

        // Use Part 1's is_null to skip missing values.
        if is_null(&agency) || is_null(created) || is_null(closed) {
            continue;
        }

        if let Some(days) = days_between(created, closed) {
            out.push(ServiceRequest { agency, resolution_days: days });
        }
    }

    Ok(out)
}

fn load_salaries(path: &str) -> anyhow::Result<Vec<Employee>> {
    let f = File::open(path)
        .map_err(|_| ProfilerError::FileNotFound { path: path.to_string() })
        .with_context(|| format!("Cannot open salaries file: {path}"))?;

    let data = CsvIngestor::ingest(f)
        .with_context(|| format!("Failed to parse salaries CSV: {path}"))?;

    let col = |name: &str| -> anyhow::Result<usize> {
        data.headers
            .iter()
            .position(|h| h.eq_ignore_ascii_case(name))
            .with_context(|| format!("Column '{name}' not found in {path}"))
    };

    let agency_idx  = col("agencyName")?;
    let pay_idx     = col("grossPay")?;

    let n = data.column_values[0].len();
    let mut out = Vec::with_capacity(n);

    for i in 0..n {
        let agency  = data.column_values[agency_idx][i].trim().to_string();
        let pay_raw = &data.column_values[pay_idx][i];

        if is_null(&agency) || is_null(pay_raw) {
            continue;
        }

        // Strip '$' or commas that sometimes appear in portal exports.
        let clean: String = pay_raw
            .chars()
            .filter(|c| c.is_ascii_digit() || *c == '.')
            .collect();

        if let Ok(pay) = clean.parse::<f64>() {
            // Skip zero-pay rows (election judges, unpaid positions, etc.)
            if pay > 0.0 {
                out.push(Employee { agency_name: agency, gross_pay: pay });
            }
        }
    }

    Ok(out)
}

// ── Join & aggregate ──────────────────────────────────────────────────────────

fn aggregate(requests: &[ServiceRequest], employees: &[Employee]) -> Vec<AgencyStats> {
    let mut req_map: HashMap<String, Vec<f64>> = HashMap::new();
    let mut sal_map: HashMap<String, Vec<f64>> = HashMap::new();

    for r in requests {
        req_map.entry(r.agency.clone()).or_default().push(r.resolution_days);
    }
    for e in employees {
        sal_map.entry(e.agency_name.clone()).or_default().push(e.gross_pay);
    }

    // Inner join on agency name — only agencies present in both datasets.
    let mut stats: Vec<AgencyStats> = req_map
        .iter()
        .filter_map(|(agency, days)| {
            let pays = sal_map.get(agency)?;
            let avg_days = days.iter().sum::<f64>() / days.len() as f64;
            let avg_pay  = pays.iter().sum::<f64>() / pays.len() as f64;
            Some(AgencyStats {
                name: agency.clone(),
                request_count: days.len(),
                avg_resolution_days: avg_days,
                employee_count: pays.len(),
                avg_gross_pay: avg_pay,
            })
        })
        .collect();

    // Sort by avg gross pay descending for a readable table.
    stats.sort_by(|a, b| b.avg_gross_pay.partial_cmp(&a.avg_gross_pay).unwrap());
    stats
}

// ── Pearson r ─────────────────────────────────────────────────────────────────

fn pearson(xs: &[f64], ys: &[f64]) -> Option<f64> {
    let n = xs.len();
    if n < 2 { return None; }
    let mx = xs.iter().sum::<f64>() / n as f64;
    let my = ys.iter().sum::<f64>() / n as f64;
    let cov: f64 = xs.iter().zip(ys).map(|(x, y)| (x - mx) * (y - my)).sum();
    let sx: f64  = xs.iter().map(|x| (x - mx).powi(2)).sum::<f64>().sqrt();
    let sy: f64  = ys.iter().map(|y| (y - my).powi(2)).sum::<f64>().sqrt();
    if sx == 0.0 || sy == 0.0 { return None; }
    Some(cov / (sx * sy))
}

// ── Output ────────────────────────────────────────────────────────────────────

fn print_results(stats: &[AgencyStats]) {
    println!();
    println!(
        "{}",
        " balt-correlate — 311 Resolution Speed × Agency Salary Level "
            .on_bright_blue().bold().white()
    );
    println!(
        "  {} agencies matched across both datasets\n",
        stats.len().to_string().bold()
    );

    // Per-agency table
    let mut table = Table::new();
    table
        .load_preset(UTF8_FULL)
        .set_content_arrangement(ContentArrangement::Dynamic)
        .set_header(vec![
            Cell::new("Agency").fg(Color::Cyan).set_alignment(CellAlignment::Left),
            Cell::new("Avg Gross Pay ($)").fg(Color::Cyan).set_alignment(CellAlignment::Right),
            Cell::new("Employees").fg(Color::Cyan).set_alignment(CellAlignment::Right),
            Cell::new("Avg Days to Close").fg(Color::Cyan).set_alignment(CellAlignment::Right),
            Cell::new("311 Requests").fg(Color::Cyan).set_alignment(CellAlignment::Right),
        ]);

    for s in stats {
        table.add_row(vec![
            s.name.clone(),
            format!("{:>10.2}", s.avg_gross_pay),
            s.employee_count.to_string(),
            format!("{:>6.1}", s.avg_resolution_days),
            s.request_count.to_string(),
        ]);
    }
    println!("{table}");

    // Pearson correlation
    let pays: Vec<f64> = stats.iter().map(|s| s.avg_gross_pay).collect();
    let days: Vec<f64> = stats.iter().map(|s| s.avg_resolution_days).collect();

    println!("\n{}", " Correlation Analysis ".on_bright_black().white().bold());

    match pearson(&pays, &days) {
        Some(r) => {
            let strength = match r.abs() {
                v if v >= 0.7 => "strong",
                v if v >= 0.4 => "moderate",
                v if v >= 0.2 => "weak",
                _             => "negligible",
            };
            let direction = if r < 0.0 { "negative" } else { "positive" };
            println!();
            println!(
                "  Pearson r (avg agency pay vs avg days to close): {:.4}",
                r
            );
            println!("  Interpretation: {} {} correlation", strength.bold(), direction);
            println!();
            if r < -0.2 {
                println!(
                    "  {} Agencies with higher average gross pay tend to close \
                     311 requests faster.",
                    "→".green().bold()
                );
            } else if r > 0.2 {
                println!(
                    "  {} Agencies with higher average gross pay do NOT close \
                     requests faster — higher pay correlates with slower closure.",
                    "→".yellow().bold()
                );
            } else {
                println!(
                    "  {} No meaningful linear relationship between \
                     agency salary level and 311 resolution speed.",
                    "→".white().bold()
                );
            }
        }
        None => println!("  Not enough matched agencies to compute correlation (need ≥ 2)."),
    }

    // Extremes
    let mut by_speed: Vec<&AgencyStats> = stats.iter().collect();
    by_speed.sort_by(|a, b| a.avg_resolution_days.partial_cmp(&b.avg_resolution_days).unwrap());

    println!("\n{}", " Fastest vs Slowest Agencies ".on_bright_black().white().bold());
    println!();
    println!("  {} Fastest average resolution:", "▲".green());
    for s in by_speed.iter().take(3) {
        println!(
            "    {:<35} {:5.1} days  (avg pay ${:.0})",
            s.name, s.avg_resolution_days, s.avg_gross_pay
        );
    }
    println!();
    println!("  {} Slowest average resolution:", "▼".red());
    for s in by_speed.iter().rev().take(3) {
        println!(
            "    {:<35} {:5.1} days  (avg pay ${:.0})",
            s.name, s.avg_resolution_days, s.avg_gross_pay
        );
    }
    println!();
}

// ── Optional csvprof summaries ────────────────────────────────────────────────

fn run_profile(path: &str, label: &str) -> anyhow::Result<()> {
    use std::io;
    let reader: Box<dyn io::Read> = Box::new(
        File::open(path)
            .map_err(|_| ProfilerError::FileNotFound { path: path.to_string() })
            .with_context(|| format!("Cannot open {path}"))?,
    );

    let data = CsvIngestor::ingest(reader)
        .with_context(|| format!("Failed to parse {path}"))?;

    let opts = ProfilerOptions { percentiles: false, histogram: false };
    let profiler = DispatchProfiler;

    let profiles: Vec<_> = data.headers.iter()
        .zip(data.column_values.iter())
        .map(|(name, values)| {
            let t = infer_type(values);
            profiler.profile(name, values, t, &opts)
        })
        .collect();

    csvprof::report::print_report(&profiles, label);
    Ok(())
}

// ── Entry point ───────────────────────────────────────────────────────────────

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    if cli.profile {
        run_profile(&cli.requests, "311 Service Requests")?;
        run_profile(&cli.salaries, "Baltimore City Employee Salaries")?;
    }

    let requests  = load_requests(&cli.requests)?;
    let employees = load_salaries(&cli.salaries)?;

    println!(
        "\n  Loaded {} closed 311 requests and {} salary records.",
        requests.len().to_string().bold(),
        employees.len().to_string().bold()
    );

    let stats = aggregate(&requests, &employees);

    if stats.is_empty() {
        anyhow::bail!(
            "No agencies matched between the two datasets.\n\
             Check that the 'Agency' values in the 311 CSV match \
             the 'agencyName' values in the salaries CSV."
        );
    }

    print_results(&stats);
    Ok(())
}
