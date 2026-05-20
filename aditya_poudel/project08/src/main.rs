mod loader;
mod model;
mod render;

use clap::Parser;
use std::fs;

// ── Reuse Part 1 modules ──────────────────────────────────────────────────────
use csvprof::error::Result;
use csvprof::profiler::{ProfileOptions, Profiler, CsvSource};
use csvprof::report::ReportRenderer;

use loader::{join_on_neighborhood, load_arrests, load_vacants};
use model::NeighborhoodStats;
use render::{print_banner, print_correlation, print_neighborhood_table, print_summary_stats};

/// Baltimore Vacant Buildings × BPD Arrests Correlator (Project 08)
#[derive(Parser, Debug)]
#[command(name = "balt_correlate", about = "Correlates vacant buildings with arrest rates by neighborhood", version)]
struct Cli {
    /// Path to BPD_Arrests.csv
    #[arg(long, default_value = "data/BPD_Arrests.csv")]
    arrests: String,

    /// Path to Vacant_Building_Notices.csv
    #[arg(long, default_value = "data/Vacant_Building_Notices.csv")]
    vacants: String,

    /// Directory to write profile reports into
    #[arg(long, default_value = "reports")]
    reports_dir: String,

    /// How many top/bottom neighborhoods to show
    #[arg(long, default_value_t = 10)]
    top_n: usize,
}

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    fs::create_dir_all(&cli.reports_dir).ok();

    // ── Step 1: Load & profile both files (reuses Part 1 infrastructure) ─
    print_banner("Step 1 — Loading & profiling BPD_Arrests.csv");
    let (arrests, arrest_accs) = load_arrests(&cli.arrests)?;
    println!("  Loaded {} arrest records", arrests.len());
    save_text_profile(&arrest_accs, &cli.arrests, &cli.reports_dir, "arrests_profile.txt");
    run_csvprof_json(&cli.arrests, &cli.reports_dir, "arrests_profile.json")?;

    print_banner("Step 2 — Loading & profiling Vacant_Building_Notices.csv");
    let (vacants, vacant_accs) = load_vacants(&cli.vacants)?;
    println!("  Loaded {} vacant building notices", vacants.len());
    save_text_profile(&vacant_accs, &cli.vacants, &cli.reports_dir, "vacants_profile.txt");
    run_csvprof_json(&cli.vacants, &cli.reports_dir, "vacants_profile.json")?;

    // ── Step 2: Join on Neighborhood ─────────────────────────────────────
    print_banner("Step 3 — Joining datasets on Neighborhood");
    let stats = join_on_neighborhood(&arrests, &vacants);
    println!("  {} neighborhoods appear in both datasets", stats.len());

    // ── Step 3: Summary tables ────────────────────────────────────────────
    print_banner("Step 4 — Neighborhood Summary");
    print_summary_stats(&stats);

    // ── Step 4: Full table ────────────────────────────────────────────────
    print_banner("Step 5 — All matched neighborhoods (sorted by vacancy count)");
    print_neighborhood_table(&stats);

    // ── Step 5: Pearson correlation ───────────────────────────────────────
    let r = NeighborhoodStats::pearson_correlation(&stats);
    print_correlation(r, stats.len());

    // ── Step 6: Save correlation report ──────────────────────────────────
    save_correlation_report(&stats, r, &cli.reports_dir);
    println!("  Reports saved to {}/", cli.reports_dir);

    Ok(())
}

/// Save a plain-text profile built from Part 1 ColumnAccumulators.
fn save_text_profile(
    accs: &[csvprof::stats::ColumnAccumulator],
    source: &str,
    dir: &str,
    filename: &str,
) {
    let mut out = format!("csvprof report — {}\n{}\n\n", source, "=".repeat(60));
    for a in accs {
        out.push_str(&format!(
            "Column : {}\n  Rows  : {}  Nulls: {} ({:.1}%)  Unique: {}\n",
            a.name,
            a.row_count,
            a.null_count,
            a.null_pct(),
            a.unique_tracker.count(),
        ));
        if a.stats.count > 0 {
            if let Some(m) = a.stats.mean() {
                out.push_str(&format!("  Mean  : {:.2}", m));
            }
            if let Some(sd) = a.stats.std_dev() {
                out.push_str(&format!("  StdDev: {:.2}", sd));
            }
            out.push('\n');
        }
        for w in &[] as &[&str] {
            out.push_str(&format!("  WARN  : {}\n", w));
        }
        out.push('\n');
    }
    let path = format!("{}/{}", dir, filename);
    fs::write(&path, &out).ok();
    println!("  Profile saved → {path}");
}

/// Run Part 1's Profiler and save JSON report.
fn run_csvprof_json(csv_path: &str, dir: &str, filename: &str) -> Result<()> {
    use std::fs::File;
    use std::io::BufReader;
    use csvprof::error::ProfileError;

    let f = File::open(csv_path).map_err(|_| ProfileError::FileNotFound { path: csv_path.into() })?;
    let mut reader = csv::ReaderBuilder::new().has_headers(true).from_reader(BufReader::new(f));
    let headers: Vec<String> = reader.headers()?.iter().map(|s| s.to_string()).collect();

    let options = ProfileOptions {
        percentiles: true,
        histogram: false,
        categorical_threshold: 0.15,
        reservoir_size: 5000,
        ..Default::default()
    };

    let profiler = Profiler::new(options);
    let mut source = CsvSource::new(reader);
    let reports = profiler.profile(headers, &mut source)?;

    let json = serde_json::to_string_pretty(&reports).unwrap_or_default();
    let path = format!("{}/{}", dir, filename);
    fs::write(&path, json).ok();
    println!("  JSON profile saved → {path}");
    Ok(())
}

/// Save the full correlation results table to a text file.
fn save_correlation_report(stats: &[NeighborhoodStats], r: f64, dir: &str) {
    let mut out = String::new();
    out.push_str("Baltimore Vacant Buildings × BPD Arrests — Correlation Report\n");
    out.push_str(&"=".repeat(65));
    out.push('\n');
    out.push_str(&format!("\nPearson r = {:.4}  (n = {} neighborhoods)\n", r, stats.len()));
    out.push_str(&format!("Interpretation: {}\n\n", NeighborhoodStats::interpret(r)));
    out.push_str(&format!("{:<35} {:>8} {:>9} {:>12}\n",
        "Neighborhood", "Vacants", "Arrests", "Ratio"));
    out.push_str(&"-".repeat(65));
    out.push('\n');
    for s in stats {
        out.push_str(&format!("{:<35} {:>8} {:>9} {:>12.2}\n",
            s.neighborhood, s.vacant_count, s.arrest_count, s.arrests_per_vacant));
    }
    let path = format!("{}/correlation_results.txt", dir);
    fs::write(&path, &out).ok();
    println!("  Correlation report → {path}");
}