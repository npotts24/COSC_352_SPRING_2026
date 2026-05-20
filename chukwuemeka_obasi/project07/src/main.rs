mod csv_profiler;
mod profiler;
mod utils;

use clap::Parser;
use csv_profiler::CsvProfiler;
use profiler::TypeBasedProfilerFactory;

#[derive(Parser)]
#[command(name = "csvprof")]
struct Args {
    /// Path to CSV file (use - for stdin later if you extend)
    file: String,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let profiler = CsvProfiler::new(TypeBasedProfilerFactory);

    for summary in profiler.analyze_file(&args.file)? {
        println!("Column: {}", summary.header);
        println!("{}", summary.report);
        println!("----------------------------------");
    }

    Ok(())
}
