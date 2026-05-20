use crate::cli::Args;
use crate::column::{ColumnProfile, DataType};
use crate::stats;
use std::collections::{HashMap, HashSet};
use std::error::Error;

pub fn run(args: &Args) -> Result<(), Box<dyn Error>> {
    let mut reader = csv::Reader::from_path(&args.file)?;
    let headers = reader.headers()?.clone();

    let mut cols: Vec<ColumnProfile> = headers
        .iter()
        .map(|h| ColumnProfile {
            name: h.to_string(),
            dtype: DataType::Integer,
            row_count: 0,
            null_count: 0,
            unique: HashSet::new(),
            freq: HashMap::new(),
            values: Vec::new(),
        })
        .collect();

    for result in reader.records() {
        let record = result?;

        for (i, field) in record.iter().enumerate() {
            let col = &mut cols[i];
            col.row_count += 1;

            let val = field.trim();

            if val.is_empty() || val == "NA" {
                col.null_count += 1;
                continue;
            }

            col.unique.insert(val.to_string());
            *col.freq.entry(val.to_string()).or_insert(0) += 1;

            let is_int = val.parse::<i64>().is_ok();
            let is_float = val.parse::<f64>().is_ok();
            let is_bool = val == "true" || val == "false";

            match col.dtype {
                DataType::Integer => {
                    if is_int {
                        col.values.push(val.parse::<f64>().unwrap());
                    } else if is_float {
                        col.dtype = DataType::Float;
                        col.values.push(val.parse::<f64>().unwrap());
                    } else if is_bool {
                        col.dtype = DataType::Boolean;
                    } else {
                        col.dtype = DataType::Text;
                    }
                }
                DataType::Float => {
                    if is_float {
                        col.values.push(val.parse::<f64>().unwrap());
                    } else {
                        col.dtype = DataType::Mixed;
                    }
                }
                DataType::Boolean => {
                    if !is_bool {
                        col.dtype = DataType::Mixed;
                    }
                }
                DataType::Text => {}
                DataType::Mixed => {}
            }
        }
    }

    // REPORT
    for col in cols {
        println!("======================");
        println!("Column: {}", col.name);
        println!("Type: {:?}", col.dtype);
        println!("Rows: {}", col.row_count);
        println!(
            "Nulls: {} ({:.2}%)",
            col.null_count,
            (col.null_count as f64 / col.row_count as f64) * 100.0
        );

        println!("Unique: {}", col.unique.len());

        if matches!(col.dtype, DataType::Float | DataType::Integer) && !col.values.is_empty() {
            let mut vals = col.values.clone();

            println!("Min: {}", stats::min(&vals));
            println!("Max: {}", stats::max(&vals));
            println!("Mean: {}", stats::mean(&vals));
            println!("Median: {}", stats::median(&mut vals.clone()));
            println!("Std Dev: {}", stats::std_dev(&vals));

            if args.percentiles {
                println!("P5: {}", stats::percentile(&mut vals.clone(), 5.0));
                println!("P25: {}", stats::percentile(&mut vals.clone(), 25.0));
                println!("P75: {}", stats::percentile(&mut vals.clone(), 75.0));
                println!("P95: {}", stats::percentile(&mut vals.clone(), 95.0));
            }
        }

        let mut freq: Vec<_> = col.freq.iter().collect();
        freq.sort_by(|a, b| b.1.cmp(a.1));

        println!("Top values:");
        for (k, v) in freq.iter().take(5) {
            println!("  {}: {}", k, v);
        }

        if args.histogram {
            println!("Histogram:");
            for (k, v) in col.freq.iter() {
                println!("{}: {}", k, "*".repeat(*v));
            }
        }

        if col.unique.len() == 1 {
            println!("⚠ Constant column");
        }

        if matches!(col.dtype, DataType::Text) && col.unique.len() < 10 {
            println!("⚠ Low cardinality categorical");
        }

        if matches!(col.dtype, DataType::Mixed) {
            println!("⚠ Mixed type column");
        }
    }

    Ok(())
}