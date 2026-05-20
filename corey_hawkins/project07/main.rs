use clap::Parser;

use std::path::PathBuf;

# [derive(Parser, Debug)]

# [command(author, version, about, long_about = None)]

struct Args {

    // Path to the input CSV file

    #[arg(short, long)]

    file: PathBuf,

    // Enable percentile calculations 

    #[arg(long)]

    enable_percentiles: bool,

    // Enable value frequency histogram for categorical columns

    #[arg(long)]

    enable_histogram: bool,

    // Output format

    #[arg(long, default_value = "human")]

    format: String,

}

fn main() -> anyhow::Result<()> {

    let args = Args::parse();

    println!("Profiling file")
