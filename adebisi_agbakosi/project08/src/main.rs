use csvprof::{ColumnAnalyzer, StatsAnalyzer};
use clap::Parser;
use std::fs::File;
use std::path::PathBuf;
use csv::ReaderBuilder;

#[derive(Parser, Debug)]
struct Args { file: PathBuf }

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let mut rdr = ReaderBuilder::new().from_reader(File::open(&args.file)?);
    let headers = rdr.headers()?.clone();
    let mut analyzers: Vec<StatsAnalyzer> = headers.iter().map(|_| StatsAnalyzer::new()).collect();

    for result in rdr.records() {
        let record = result?;
        for (i, field) in record.iter().enumerate() {
            analyzers[i].update(field);
        }
    }
    println!("Profile for {:?}", args.file);
    Ok(())
}