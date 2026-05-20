// Declares modules
mod profiler;
mod stats;
mod types;

// Imports parser and CsvProfiler into the code
use clap::Parser;
use profiler::CsvProfiler;

// Defines the argumets used for the code
struct Cli{
    file: String,
    delimiter: char,
}

// Function to read the file and run the profiler
fn main() -> anyhow::Result<()> {
    let args = Cli::parse();
    let profiler = CsvProfiler::new(args.delimiter);
    profiler.run(&args.file)?;
    Ok(())
}