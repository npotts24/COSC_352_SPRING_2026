use clap::Parser;

/// csvprof — A command-line CSV data profiling tool.
///
/// Ingests any CSV file and produces a structured report describing the shape,
/// quality, and statistical characteristics of each column. Streams rows so
/// that even very large files can be profiled without loading them entirely
/// into memory.
#[derive(Parser, Debug, Clone)]
#[command(name = "csvprof", version, about, long_about = None)]
pub struct Args {
    /// Path to input CSV file (use `-` for stdin)
    pub file: String,

    /// Delimiter character (default: comma)
    #[arg(short, long, default_value = ",")]
    pub delimiter: char,

    /// Show percentile statistics (p5 / p25 / p75 / p95) for numeric columns
    #[arg(short, long)]
    pub percentiles: bool,

    /// Show value frequency histogram for categorical / boolean columns
    #[arg(long)]
    pub histogram: bool,

    /// Output format: table (default), json
    #[arg(short, long, default_value = "table")]
    pub format: OutputFormat,

    /// Maximum number of unique values before a column is classified as text
    /// rather than categorical
    #[arg(long, default_value_t = 50)]
    pub category_threshold: usize,

    /// Number of top/bottom frequent values to display for categorical columns
    #[arg(long, default_value_t = 5)]
    pub top_n: usize,

    /// Treat the first row as data (no header row)
    #[arg(long)]
    pub no_header: bool,
}

#[derive(Debug, Clone, clap::ValueEnum)]
pub enum OutputFormat {
    Table,
    Json,
}

pub fn parse_args() -> Args {
    Args::parse()
}