mod cli;
mod profiler;
mod column;
mod stats;

use clap::Parser;
use cli::Args;

fn main() {
    let args = Args::parse();

    if let Err(e) = profiler::run(&args) {
        eprintln!("Error: {}", e);
    }
}