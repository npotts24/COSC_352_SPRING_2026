/// CLI argument parsing using clap derive API.
use clap::Parser;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(
    name = "csvprof",
    about = "CSV data profiling tool — inspect shape, quality, and statistics of any CSV file",
    version
)]
pub struct Cli {
    /// Path to input CSV file (use `-` for stdin)
    #[arg(value_name = "FILE")]
    pub file: PathBuf,

    /// Include percentile breakdown (p5/p25/p75/p95) for numeric columns
    #[arg(short = 'p', long = "percentiles")]
    pub percentiles: bool,

    /// Show full value frequency histogram for categorical columns
    #[arg(short = 'H', long = "histogram")]
    pub histogram: bool,

    /// Number of rows to sample for type inference (0 = all rows)
    #[arg(short = 'n', long = "sample-rows", default_value_t = 1000)]
    pub sample_rows: usize,

    /// Output format
    #[arg(short = 'f', long = "format", value_enum, default_value_t = OutputFormat::Table)]
    pub format: OutputFormat,

    /// CSV delimiter character
    #[arg(short = 'd', long = "delimiter", default_value_t = ',')]
    pub delimiter: char,

    /// Treat first row as header (default: true)
    #[arg(long = "no-header")]
    pub no_header: bool,
}

#[derive(Debug, Clone, Copy, clap::ValueEnum)]
pub enum OutputFormat {
    /// Pretty-printed terminal tables
    Table,
    /// Machine-readable JSON
    Json,
}
