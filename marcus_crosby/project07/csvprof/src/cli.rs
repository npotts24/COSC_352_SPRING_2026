use std::collections::HashSet;
use std::path::PathBuf;

use clap::Parser;

use crate::error::CsvProfError;
use crate::profiler::ProfilerConfig;
use crate::types::OutputFormat;

const DEFAULT_NULLS: &[&str] = &["", "null", "na", "n/a", "none"];

#[derive(Debug, Parser)]
#[command(
    name = "csvprof",
    version,
    about = "Profile CSV files in a single streaming pass without loading them into memory"
)]
pub struct Cli {
    /// Input CSV path. Use `-` to read from stdin.
    pub file: PathBuf,
    /// Output format for the final report.
    #[arg(long, value_enum, default_value_t = OutputFormat::Markdown)]
    pub output_format: OutputFormat,
    /// Optional percentile list such as `50,90,95,99`.
    #[arg(long, value_delimiter = ',', value_parser = parse_percentile)]
    pub percentiles: Vec<f64>,
    /// CSV delimiter as a single-byte character.
    #[arg(long, default_value = ",")]
    pub delimiter: char,
    /// Treat the first row as data instead of headers.
    #[arg(long)]
    pub no_headers: bool,
    /// Number of heavy hitters to print in the report.
    #[arg(long, default_value_t = 5)]
    pub top_k: usize,
    /// Capacity for the bounded heavy-hitter sketch.
    #[arg(long, default_value_t = 32)]
    pub top_k_capacity: usize,
    /// Capacity for bounded distinct counting. Exact until this threshold, approximate afterwards.
    #[arg(long, default_value_t = 1024)]
    pub distinct_capacity: usize,
    /// Reservoir sample size used for approximate median and opt-in percentiles.
    #[arg(long, default_value_t = 4096)]
    pub sample_size: usize,
    /// Additional case-insensitive null markers, comma-separated.
    #[arg(long, value_delimiter = ',')]
    pub null_values: Vec<String>,
}

impl Cli {
    pub fn profiler_config(&self) -> Result<ProfilerConfig, CsvProfError> {
        let delimiter = u8::try_from(self.delimiter as u32)
            .map_err(|_| CsvProfError::InvalidDelimiter(self.delimiter))?;

        let mut null_values: HashSet<String> = DEFAULT_NULLS
            .iter()
            .map(|value| value.to_string())
            .collect();
        for value in &self.null_values {
            null_values.insert(value.trim().to_ascii_lowercase());
        }

        Ok(ProfilerConfig {
            delimiter,
            has_headers: !self.no_headers,
            top_k: self.top_k.max(1),
            top_k_capacity: self.top_k_capacity.max(self.top_k.max(1)),
            distinct_capacity: self.distinct_capacity.max(32),
            sample_size: self.sample_size.max(32),
            percentiles: self.percentiles.clone(),
            null_values,
        })
    }
}

fn parse_percentile(raw: &str) -> Result<f64, CsvProfError> {
    let value: f64 = raw
        .parse()
        .map_err(|_| CsvProfError::InvalidPercentile(raw.to_string()))?;
    if (0.0..=100.0).contains(&value) {
        Ok(value)
    } else {
        Err(CsvProfError::InvalidPercentile(raw.to_string()))
    }
}
