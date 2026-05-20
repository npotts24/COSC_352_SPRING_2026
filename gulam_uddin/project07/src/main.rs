mod cli;
mod error;
mod infer;
mod profile;
mod report;
mod stats;
#[cfg(test)]
mod tests;
mod types;

use std::process;

fn main() {
    let args = cli::parse_args();

    if let Err(e) = run(args) {
        eprintln!("Error: {e}");
        process::exit(1);
    }
}

fn run(args: cli::Args) -> Result<(), error::ProfilingError> {
    let profile = profile::profile_csv(&args)?;
    report::render(&profile, &args)?;
    Ok(())
}