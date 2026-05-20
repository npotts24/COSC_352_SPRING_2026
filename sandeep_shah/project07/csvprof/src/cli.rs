use clap::{Parser, ValueEnum};

#[derive(Copy, Clone, Debug, Eq, PartialEq, ValueEnum)]
pub enum OutputFormat {
    Text,
    Json,
}

#[derive(Parser, Debug)]
#[command(
    name = "csvprof",
    version,
    about = "Profile CSV files from the command line"
)]
pub struct Cli {
    /// Path to CSV file, or '-' to read from stdin
    pub file: String,

    /// Delimiter character, default ','
    #[arg(short, long, default_value = ",")]
    pub delimiter: char,

    /// Treat input as having no header row
    #[arg(long)]
    pub no_headers: bool,

    /// Include numeric percentiles p5/p25/p75/p95
    #[arg(long)]
    pub percentiles: bool,

    /// Include categorical histogram
    #[arg(long)]
    pub histogram: bool,

    /// Output format
    #[arg(long, value_enum, default_value_t = OutputFormat::Text)]
    pub format: OutputFormat,

    /// Max number of distinct values that still counts as categorical
    #[arg(long, default_value_t = 20)]
    pub max_categories: usize,

    /// If unique/non-null <= this ratio, treat as categorical
    #[arg(long, default_value_t = 0.05)]
    pub categorical_ratio: f64,
}
