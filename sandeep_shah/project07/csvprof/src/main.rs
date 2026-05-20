mod cli;
mod error;
mod profiler;
mod report;
mod stats;

use anyhow::{Result, bail};
use clap::Parser;
use cli::{Cli, OutputFormat};
use profiler::{ProfileConfig, profile_csv};
use report::{Formatter, JsonFormatter, TextFormatter};

fn main() -> Result<()> {
    let args = Cli::parse();

    if !args.delimiter.is_ascii() {
        bail!("delimiter must be a single ASCII character");
    }

    let cfg = ProfileConfig {
        delimiter: args.delimiter as u8,
        has_headers: !args.no_headers,
        percentiles: args.percentiles,
        histogram: args.histogram,
        max_categories: args.max_categories,
        categorical_ratio: args.categorical_ratio,
    };

    let report = profile_csv(&args.file, &cfg)?;

    let formatter: Box<dyn Formatter> = match args.format {
        OutputFormat::Text => Box::new(TextFormatter),
        OutputFormat::Json => Box::new(JsonFormatter),
    };

    let output = formatter.format(&report)?;
    println!("{output}");

    Ok(())
}
