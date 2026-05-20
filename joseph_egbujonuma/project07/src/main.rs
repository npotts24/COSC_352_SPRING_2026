mod profiler;
mod report;
mod types;

use clap::Parser;
use csv::ReaderBuilder;
use profiler::CsvProfiler;
use std::fs::File;
use std::io::{self, Read};

#[derive(Parser, Debug)]
#[command(name = "csvprof")]
#[command(about = "A streaming CSV data profiling tool in Rust")]
struct Args {
    /// Path to input CSV file (use - for stdin)
    file: String,

    /// Treat file as having no headers
    #[arg(long)]
    no_headers: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    let reader: Box<dyn Read> = if args.file == "-" {
        Box::new(io::stdin())
    } else {
        Box::new(File::open(&args.file)?)
    };

    let mut rdr = ReaderBuilder::new()
        .has_headers(!args.no_headers)
        .from_reader(reader);

    let headers = if args.no_headers {
        None
    } else {
        Some(rdr.headers()?.clone())
    };

    let mut profiler = CsvProfiler::new(headers);

    for result in rdr.records() {
        let record = result?;
        profiler.process_record(&record);
    }

    report::print_report(&profiler);

    Ok(())
}