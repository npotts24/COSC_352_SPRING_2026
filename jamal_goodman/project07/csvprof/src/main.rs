mod profiler;
mod stats;
mod types;
mod error;

use clap::Parser;
use profiler::Profiler;
use std::path::PathBuf;

#[derive(Parser, Debug)]
#[command(author, version, about)]
struct Args {
    /// Input CSV file (or - for stdin)
    file: String,

    /// Delimiter (default: ,)
    #[arg(short, long, default_value = ",")]
    delimiter: char,

    /// Output format (text/json)
    #[arg(short, long, default_value = "text")]
    format: String,

    /// Enable percentiles
    #[arg(long)]
    percentiles: bool,
}

fn main() {
    let args = Args::parse();

    let path = if args.file == "-" {
        None
    } else {
        Some(PathBuf::from(args.file))
    };

    let mut profiler = Profiler::new(args.percentiles);

    if let Err(e) = profiler.process(path, args.delimiter as u8) {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }

    profiler.print_report(&args.format);
}