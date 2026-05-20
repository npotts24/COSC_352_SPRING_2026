mod csv_reader;
mod analyzer;
mod error;
mod part2;

use csv_reader::CsvReader;
use analyzer::{ColumnAnalyzer, BasicAnalyzer};
use std::env;

fn run_profile(path: &str) {
    let mut reader = CsvReader::new(path).expect("Failed to read CSV");

    let headers = reader.headers().clone();
    let mut analyzers: Vec<BasicAnalyzer> =
        headers.iter().map(|_| BasicAnalyzer::new()).collect();

    while let Some(row) = reader.next_row() {
        for (i, value) in row.iter().enumerate() {
            analyzers[i].process(value);
        }
    }

    for (i, analyzer) in analyzers.iter().enumerate() {
        println!("Column: {}", headers[i]);
        println!("{}", analyzer.report());
    }
}