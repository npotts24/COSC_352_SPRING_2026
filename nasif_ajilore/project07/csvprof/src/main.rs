/// csvprof — a command-line CSV data profiling tool.
///
/// Ingests any CSV file and produces a structured report describing the shape,
/// quality, and statistical characteristics of each column.  Rows are streamed
/// so the tool can handle files larger than available memory.
mod cli;
mod error;
mod infer;
mod reader;
mod report;
mod stats;
mod types;

use std::process;

use clap::Parser;

use cli::{Cli, OutputFormat};

fn main() {
    let args = Cli::parse();

    let delimiter = args.delimiter as u8;
    let has_header = !args.no_header;

    let profiles = match reader::profile_csv(
        &args.file,
        delimiter,
        has_header,
        args.percentiles,
        args.histogram,
    ) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("csvprof: {e}");
            process::exit(1);
        }
    };

    let json = matches!(args.format, OutputFormat::Json);
    report::render(&profiles, json);
}
