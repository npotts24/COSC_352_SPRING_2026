//! csvprof - A production-quality CSV data profiling tool.
//!
//! This binary uses the shared `csvprof` library to parse, infer, profile, and render
//! reports for CSV files.

use anyhow::Result;
use clap::Parser;
use csvprof::{cli::Args, output, profile_csv_content, read_input, ProfileConfig};

fn main() -> Result<()> {
    let args = Args::parse();

    // Validate delimiter
    let delimiter = if args.delimiter.len() != 1 {
        return Err(anyhow::anyhow!("Invalid delimiter: {}", args.delimiter));
    } else {
        args.delimiter.chars().next().unwrap() as u8
    };

    let input_desc = if args.file == "-" {
        "stdin".to_string()
    } else {
        args.file.clone()
    };

    let file_content = read_input(&args.file)?;
    let config = ProfileConfig {
        delimiter,
        no_header: args.no_header,
        max_unique: args.max_unique,
        percentiles: args.percentiles,
        top_n: args.top_n,
        hist: args.hist,
    };

    let report = profile_csv_content(&file_content, input_desc, &config)?;

    let mut output: Box<dyn std::io::Write> = if let Some(output_path) = args.output {
        Box::new(std::fs::File::create(&output_path)?)
    } else {
        Box::new(std::io::stdout())
    };

    if args.json {
        output::render_json(&report, &mut *output)?;
    } else {
        output::render_terminal(&report, &mut *output)?;
    }

    Ok(())
}
