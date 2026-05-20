//! `csvprof` — Part 1 CLI entry point.

use clap::{Parser, ValueEnum};
use csvprof::{
    analyzer::AnalyzerOptions,
    profile::Profiler,
    reader::StreamingCsvReader,
    Result,
};
use std::process::ExitCode;

/// A streaming CSV profiler with type inference.
#[derive(Parser, Debug)]
#[command(
    name = "csvprof",
    version,
    about = "Profile a CSV file: infer types, compute statistics, flag quality issues.",
    long_about = None,
)]
struct Cli {
    /// Path to input CSV file (use `-` for stdin).
    file: String,

    /// Output format.
    #[arg(short, long, value_enum, default_value_t = Format::Table)]
    format: Format,

    /// Include p5/p25/p75/p95 for numeric columns.
    #[arg(long)]
    percentiles: bool,

    /// Include full value-frequency histogram for categorical columns.
    #[arg(long)]
    histogram: bool,

    /// Cardinality threshold above which text is NOT considered categorical.
    #[arg(long, default_value_t = 32)]
    categorical_threshold: usize,

    /// Cap on distinct values tracked per column (memory guard).
    #[arg(long, default_value_t = 100_000)]
    distinct_cap: usize,
}

#[derive(Copy, Clone, Debug, ValueEnum)]
enum Format {
    /// Human-readable terminal table with colored warnings.
    Table,
    /// Pretty-printed JSON.
    Json,
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();

    let opts = AnalyzerOptions {
        percentiles: cli.percentiles,
        histogram:   cli.histogram,
        categorical_threshold: cli.categorical_threshold,
        distinct_cap: cli.distinct_cap,
    };

    let mut reader = StreamingCsvReader::open(&cli.file)?;
    let profiler = Profiler::with_options(cli.file.clone(), opts);
    let report = profiler.run(&mut reader)?;

    match cli.format {
        Format::Table => println!("{}", report.render_table()),
        Format::Json  => println!("{}", report.to_json()?),
    }
    Ok(())
}
