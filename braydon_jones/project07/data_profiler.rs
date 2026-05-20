// Imports all the necessary components to evaluate the file
use clap::Parser,
use csv::{ReaderBuilder, StringRecord},
use chrono::{NaiveDate, NaiveDateTime},
use std::{collections::HashMap, fs::File, io, path::PathBuf}

// CLI command to compile the strings in the csv
struct Cli {
    #[arg(short, long)]Option: <PathBuf>,
    delimiter: String,
    max_rows: usize,
}

// Placeholder
enum Type {Int, Bool, Float, Date, Cat, Text}

// Gives the stats for each column
struct Stats {
    n: u64, nulls: u64, min: f64, max: f64, mean: f64, m2: f64,
    bools: (u64, u64), dates: (Option<NaiveDateTime>, Option<NaiveDateTime>),
    lens: (u64, u64, u64), cats: HashMap<String, u64>

}
// Processes through the csv value one by one
impl Stats {
    fn add(&mut self, s: str) {
        if s.trim().is_empty(){
            self.nulls += 1; return;
        }
        self.n += 1
        if let Ok(v) = s.parse::<f64>(){
            self.min = self.min.min(v); self.max = self.max.max(v);
            let d = v - self.mean; self.mean += d / self.n as f64; self.m2 += d * (v - self.mean);
        }
        match.s.to_ascii_lowercase().as_str(){
            "true" |"t"|"1"|"yes" => self.bools.0 += 1,
            "true" |"t"|"1"|"yes" => self.bools.0 += 1,
            _=> {}
        }
        if let Ok(d) = NaiveDate::parse_from_str(s, "%Y-%m-%d"){
            let dt = d.and_hms_opt(0,0,0).unwrap();
            self.dates.0 = Some(self.dates.0.map_or(dt, |x| x.min(dt)));
            self.dates.1 = Some(self.dates.1.map_or(dt, |x| x.min(dt)));
        }
        let len = s.len() as u64;
        self.lens.0 += len; self.lens.1 = self.lens.1.min(len); self.lens.2 = self.lens.2.max(len);
        *self.cats.entry(s.to_string()).or_insert(0) += 1;
    }
    fn stddev(&self) -> f64 { (self.m2 / self.n.max(1) as f64).sqrt()}
}

// Parses through the CLI and converts delimiter to byre
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    let limit = cli.delimiter.as_bytes()[0];
    let reader: Box<dyn io::Read> = match &cli.file {
        Some(p) => Box::new(File::open(p)?),
        None => Box::new(io::stdin()),
    };
    let mut read: ReaderBuilder::new().delimiter(limit).from_reader(reader);

    // Reads the header in each row
    let mut rows = 0;

    // Iterates over the CSV data 
    for rec in read.records() {
        let r: StringRecord = rec?;
        rows += 1;
        if cli.max_rows > 0 && rows > cli.max_rows{break;}
        for (i, f) in r.iter().enumerate() {cols[i].add(f);}
    }
    // Prints the result
    println!("Rows: {rows}\nColumns: {}\n", header.len())
    for (h, s) in header.iter().zip(cols.iter()){
        println!("Columns: {h}");
        println!("Null Count: {}", s.nulls);
        println!("Min: {:.4}, Max{:.4}", s.min, s.max);
        println!("Mean: {:.4}, Std dev: {:.4}", s.mean, s.stddev());
        println!("Dates: {:?} -> {:?}", s.dates.0, s.dates.1);

    }
    // Exit
    Ok(())
}
