use clap::Parser;

#[derive(Debug, Parser)]
#[command(name = "csvprof", version, about = "CSV data profiling tool")]
pub struct Args {
    #[arg(help = "Path to CSV file, use - for stdin")]
    pub file: String,

    #[arg(short = 'p', long = "percentiles", help = "Show p5/p25/p75/p95 percentiles")]
    pub percentiles: bool,

    #[arg(short = 'H', long = "histogram", help = "Show value frequency histogram for categoricals")]
    pub histogram: bool,

    #[arg(short = 'j', long = "json", help = "Emit JSON output instead of table")]
    pub json: bool,

    #[arg(long = "sample-rows", help = "Only profile first N rows")]
    pub sample_rows: Option<usize>,
}
