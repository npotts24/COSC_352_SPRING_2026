//! Command-line argument definitions (clap derive API).

use clap::Parser;

/// csvprof — streaming CSV data profiler
#[derive(Parser, Debug)]
#[command(
    name    = "csvprof",
    version = "1.0.0",
    author  = "csvprof",
    about   = "Profile any CSV file: types, statistics, quality checks",
    long_about = None,
)]
pub struct Cli {
    /// Path to the CSV file to profile. Use `-` to read from stdin.
    pub file: String,

    /// Show extended percentiles: p5, p25, p75, p95 (numeric columns only).
    #[arg(long, short = 'p', default_value_t = false)]
    pub percentiles: bool,

    /// Show full value frequency histogram for categorical/boolean columns.
    #[arg(long, short = 'H', default_value_t = false)]
    pub histogram: bool,

    /// Output the profile as JSON (machine-readable) instead of a table.
    #[arg(long, short = 'j', default_value_t = false)]
    pub json: bool,

    /// Unique-value threshold below which a column is classed as Categorical.
    #[arg(long, default_value_t = 50)]
    pub categorical_threshold: usize,

    /// Maximum number of distinct values tracked in the frequency map.
    /// Columns that exceed this limit will emit a warning.
    #[arg(long, default_value_t = 10_000)]
    pub max_categories: usize,

    /// Custom delimiter character (default: comma).
    #[arg(long, short = 'd', default_value_t = ',')]
    pub delimiter: char,
}
