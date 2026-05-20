use clap::Parser;
use std::fs::File;
use csv::Reader;
use anyhow::Result;

#[derive(Parser)]
struct Args {
    file: String,

    #[arg(long)]
    percentiles: bool,
}

#[derive(Debug)]
enum DataType {
    Integer,
    Float,
    Text,
}

#[derive(Debug)]
struct ColumnProfile {
    name: String,
    dtype: DataType,
    count: usize,
    nulls: usize,
    min: Option<f64>,
    max: Option<f64>,
    sum: f64,
}

fn main() -> Result<()> {
    let args = Args::parse();

    let file = File::open(&args.file)?;
    let mut rdr = Reader::from_reader(file);

    let headers = rdr.headers()?.clone();

    let mut profiles: Vec<ColumnProfile> = headers
        .iter()
        .map(|h| ColumnProfile {
            name: h.to_string(),
            dtype: DataType::Integer,
            count: 0,
            nulls: 0,
            min: None,
            max: None,
            sum: 0.0,
        })
        .collect();

    for result in rdr.records() {
        let record = result?;

        for (i, value) in record.iter().enumerate() {
            let col = &mut profiles[i];

            if value.trim().is_empty() {
                col.nulls += 1;
                continue;
            }

            col.count += 1;

            if let Ok(v) = value.parse::<f64>() {
                col.dtype = DataType::Float;
                col.min = Some(col.min.map_or(v, |m| m.min(v)));
                col.max = Some(col.max.map_or(v, |m| m.max(v)));
                col.sum += v;
            } else {
                col.dtype = DataType::Text;
            }
        }
    }

    println!("\n===== DATA PROFILE =====");

    for col in profiles {
        let total = col.count + col.nulls;

        println!("Column: {}", col.name);
        println!("Type: {:?}", col.dtype);
        println!("Count: {}", col.count);
        println!("Nulls: {}", col.nulls);

        if total > 0 {
            println!("Null %: {:.2}", (col.nulls as f64 / total as f64) * 100.0);
        }

        if let Some(min) = col.min {
            println!("Min: {}", min);
        }

        if let Some(max) = col.max {
            println!("Max: {}", max);
        }

        if col.count > 0 {
            println!("Mean: {}", col.sum / col.count as f64);
        }

        println!("----------------------");
    }

    Ok(())
}