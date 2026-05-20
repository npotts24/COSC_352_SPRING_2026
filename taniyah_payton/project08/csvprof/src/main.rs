mod error;
mod ingest;
mod output_json;
mod profile;
mod profilers;
mod report;
mod stats;
mod types;

use std::{fs::File, io};

use anyhow::Context;
use clap::Parser;

use error::ProfilerError;
use ingest::CsvIngestor;
use profile::{Profiler, ProfilerOptions};
use profilers::DispatchProfiler;
use types::infer_type;

// ── CLI definition ─────────────────────────────────────────────────────────────

/// csvprof — Fast, streaming CSV data profiler
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to input CSV file (use `-` for stdin)
    file: String,

    /// Output format: human (default) or json
    #[arg(long, short, default_value = "human")]
    format: String,

    /// Include p5/p25/p75/p95 percentiles for numeric columns
    #[arg(long, short)]
    percentiles: bool,

    /// Include full value-frequency histogram for categorical columns
    #[arg(long, short = 'H')]
    histogram: bool,

    /// Only profile columns matching these names (comma-separated)
    #[arg(long, short)]
    columns: Option<String>,
}

// ── Entry point ────────────────────────────────────────────────────────────────

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // ── Ingest ───────────────────────────────────────────────────────────────
    let data = if cli.file == "-" {
        CsvIngestor::ingest(io::stdin())
            .with_context(|| "Failed to read CSV from stdin")?
    } else {
        let f = File::open(&cli.file)
            .map_err(|_| ProfilerError::FileNotFound { path: cli.file.clone() })
            .with_context(|| format!("Cannot open file: {}", cli.file))?;
        CsvIngestor::ingest(f)
            .with_context(|| format!("Failed to parse CSV: {}", cli.file))?
    };

    // ── Optional column filter ────────────────────────────────────────────────
    let filter: Option<Vec<&str>> = cli.columns.as_deref().map(|s| s.split(',').collect());

    let opts = ProfilerOptions {
        percentiles: cli.percentiles,
        histogram: cli.histogram,
    };

    let profiler = DispatchProfiler;

    // ── Profile each column ───────────────────────────────────────────────────
    let profiles: Vec<_> = data
        .headers
        .iter()
        .zip(data.column_values.iter())
        .filter(|(name, _)| {
            filter
                .as_ref()
                .map(|f| f.contains(&name.as_str()))
                .unwrap_or(true)
        })
        .map(|(name, values)| {
            let inferred_type = infer_type(values);
            profiler.profile(name, values, inferred_type, &opts)
        })
        .collect();

    // ── Emit ──────────────────────────────────────────────────────────────────
    match cli.format.as_str() {
        "json" => output_json::emit_json(&profiles)?,
        _ => report::print_report(&profiles, &cli.file),
    }

    Ok(())
}
