//! CLI argument parsing using clap derive macros.

use clap::Parser;
use std::path::PathBuf;

/// A production-quality CSV data profiling tool.
///
/// Ingests any CSV file (or stdin) and emits a structured, human-readable report
/// describing the shape, quality, and statistical profile of each column.
#[derive(Parser, Debug)]
#[command(name = "csvprof")]
#[command(about, long_about = None)]
pub struct Args {
    /// Path to CSV file (use "-" for stdin)
    #[arg(value_name = "FILE")]
    pub file: String,

    /// Field delimiter character
    #[arg(short, long, default_value = ",")]
    pub delimiter: String,

    /// Treat first row as data, not header
    #[arg(short = 'n', long)]
    pub no_header: bool,

    /// Include p5/p25/p75/p95 percentiles in numeric stats
    #[arg(long)]
    pub percentiles: bool,

    /// Number of top/bottom frequent values to show
    #[arg(long, default_value = "5")]
    pub top_n: usize,

    /// Show value frequency histogram for categorical columns
    #[arg(long)]
    pub hist: bool,

    /// Emit report as JSON instead of tables
    #[arg(long)]
    pub json: bool,

    /// Maximum unique threshold for categorical vs text detection
    #[arg(long, default_value = "50")]
    pub max_unique: usize,

    /// Write report to file instead of stdout
    #[arg(short, long)]
    pub output: Option<PathBuf>,
}
