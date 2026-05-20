use anyhow::{Context, Result};
use clap::Parser;
use csv::ReaderBuilder;
use comfy_table::Table;
use std::path::PathBuf;
use std::io::{self, BufReader};

#[derive(Parser, Debug)]
#[command(author, version, about = "A fast CSV data profiler")]
struct Args {
    /// Path to the input CSV file (use '-' for stdin)
    file: String,

    /// Show advanced percentiles
    #[arg(short, long)]
    percentiles: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Setup input: Check if file is "-" for stdin, otherwise open as file
    let reader = if args.file == "-" {
        ReaderBuilder::new().from_reader(Box::new(io::stdin()) as Box<dyn io::Read>)
    } else {
        ReaderBuilder::new().from_path(&args.file)
            .with_context(|| format!("Could not open file: {}", args.file))?
    };

    let mut rdr = reader;

    // Example: Reading records one by one (Streaming)
    for result in rdr.records() {
        let record = result?;
        // Logic for profiling goes here
        println!("{:?}", record); 
    }

    Ok(())
}