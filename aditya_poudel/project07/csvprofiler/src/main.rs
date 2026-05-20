mod error;
mod profiler;
mod report;
mod stats;
mod types;

use clap::Parser;
use std::fs::File;
use std::io::{self, BufReader};
use std::path::PathBuf;

use crate::error::{ProfileError, Result};
use crate::profiler::{CsvSource, ProfileOptions, Profiler};
use crate::report::ReportRenderer;

/// csvprof — streaming CSV data profiler
#[derive(Parser, Debug)]
#[command(
    name = "csvprof",
    about = "Fast, streaming CSV column profiler",
    version,
    long_about = "Profiles every column of a CSV file: infers types, computes statistics, \
                  detects data-quality issues, and renders a human-readable report."
)]
struct Cli {
    /// Path to the CSV file (use `-` for stdin)
    #[arg(value_name = "FILE")]
    file: PathBuf,

    /// Output results as JSON instead of a human-readable table
    #[arg(long, short = 'j')]
    json: bool,

    /// Disable ANSI colour output
    #[arg(long)]
    no_color: bool,

    /// Show p5/p25/p75/p95 percentiles for numeric columns
    #[arg(long, short = 'p')]
    percentiles: bool,

    /// Show full value-frequency histogram for categorical columns
    #[arg(long, short = 'H')]
    histogram: bool,

    /// Cardinality ratio (0-1) below which a column is treated as Categorical
    #[arg(long, default_value_t = 0.10, value_name = "RATIO")]
    categorical_threshold: f64,

    /// Reservoir size for approximate percentile computation
    #[arg(long, default_value_t = 10_000, value_name = "N")]
    reservoir: usize,

    /// CSV field delimiter character [default: ',']
    #[arg(long, default_value_t = ',', value_name = "CHAR")]
    delimiter: char,

    /// Expect a header row in the CSV
    #[arg(long, default_value_t = true, value_name = "BOOL")]
    headers: bool,
}

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {}", e);
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();

    let options = ProfileOptions {
        percentiles: cli.percentiles,
        histogram: cli.histogram,
        categorical_threshold: cli.categorical_threshold,
        reservoir_size: cli.reservoir,
        ..Default::default()
    };

    let file_label = cli.file.display().to_string();
    let delimiter = cli.delimiter as u8;

    let reports = if file_label == "-" {
        let stdin = io::stdin();
        let reader = csv::ReaderBuilder::new()
            .delimiter(delimiter)
            .has_headers(cli.headers)
            .from_reader(BufReader::new(stdin.lock()));
        profile_reader(reader, &options)?
    } else {
        if !cli.file.exists() {
            return Err(ProfileError::FileNotFound {
                path: file_label.clone(),
            });
        }
        let f = File::open(&cli.file)?;
        let reader = csv::ReaderBuilder::new()
            .delimiter(delimiter)
            .has_headers(cli.headers)
            .from_reader(BufReader::new(f));
        profile_reader(reader, &options)?
    };

    let renderer = ReportRenderer {
        json: cli.json,
        no_color: cli.no_color,
    };
    renderer.render(&reports, &file_label);

    Ok(())
}

fn profile_reader<R: io::Read>(
    mut reader: csv::Reader<R>,
    options: &ProfileOptions,
) -> Result<Vec<crate::stats::ColumnReport>> {
    let headers: Vec<String> = reader
        .headers()?
        .iter()
        .map(|s| s.to_string())
        .collect();

    if headers.is_empty() {
        return Err(ProfileError::EmptyFile);
    }

    let profiler = Profiler::new(options.clone());
    let mut source = CsvSource::new(reader);
    profiler.profile(headers, &mut source)
}