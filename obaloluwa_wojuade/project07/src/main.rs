mod cli;
mod column;
mod error;
mod profiler;
mod report;
mod stats;
mod types;

use clap::Parser;
use cli::Args;
use profiler::Profiler;
use report::Reporter;

fn main() {
    let args = Args::parse();

    let result = Profiler::profile(&args.file, &args).and_then(|profiles| {
        if args.json {
            Reporter::print_json(&profiles)
        } else {
            Reporter::print_table(&profiles, &args);
            Ok(())
        }
    });

    if let Err(err) = result {
        eprintln!("error: {err}");
        std::process::exit(1);
    }
}
