use crate::error::CsvProfError;
use crate::stats::ColumnStats;
use crate::types::DataType;
use csv::{ReaderBuilder, StringRecord};
use std::collections::HashMap;
use std::io::Read;
use std::path::PathBuf;

pub struct Profiler {
    columns: Vec<String>,
    stats: Vec<ColumnStats>,
    types: Vec<DataType>,
    percentiles: bool,
}

impl Profiler {
    pub fn new(percentiles: bool) -> Self {
        Self {
            columns: Vec::new(),
            stats: Vec::new(),
            types: Vec::new(),
            percentiles,
        }
    }

    pub fn process(&mut self, path: Option<PathBuf>, delimiter: u8) -> Result<(), CsvProfError> {
        let input: Box<dyn Read> = if let Some(p) = path {
            Box::new(std::fs::File::open(p)?)
        } else {
            Box::new(std::io::stdin())
        };

        let mut rdr = ReaderBuilder::new()
            .delimiter(delimiter)
            .from_reader(input);

        self.columns = rdr
            .headers()?
            .iter()
            .map(|s: &str| s.to_string())
            .collect::<Vec<String>>();

        self.stats = vec![ColumnStats::new(); self.columns.len()];

        for result in rdr.records() {
            let record: StringRecord = result?;
            for (i, field) in record.iter().enumerate() {
                self.stats[i].add(field);
            }
        }

        self.infer_types();
        Ok(())
    }

    fn infer_types(&mut self) {
        self.types.clear();

        for col in &self.stats {
            let mut is_int = true;
            let mut is_float = true;
            let mut is_bool = true;

            for v in &col.values {
                if v.parse::<i64>().is_err() {
                    is_int = false;
                }
                if v.parse::<f64>().is_err() {
                    is_float = false;
                }

                let lower = v.to_lowercase();
                if lower != "true" && lower != "false" {
                    is_bool = false;
                }
            }

            let dtype = if col.values.is_empty() {
                DataType::Empty
            } else if is_int {
                DataType::Integer
            } else if is_float {
                DataType::Float
            } else if is_bool {
                DataType::Boolean
            } else {
                DataType::Text
            };

            self.types.push(dtype);
        }
    }

    pub fn print_report(&self, format: &str) {
        if format == "json" {
            let mut report = Vec::new();

            for (i, name) in self.columns.iter().enumerate() {
                let col = &self.stats[i];
                let mut map = HashMap::new();

                map.insert("column", name.clone());
                map.insert("type", format!("{:?}", self.types[i]));
                map.insert("count", col.count.to_string());
                map.insert("nulls", col.nulls.to_string());
                map.insert("unique", col.unique_count().to_string());

                report.push(map);
            }

            println!("{}", serde_json::to_string_pretty(&report).unwrap());
        } else {
            println!("CSV PROFILE REPORT\n");

            for (i, name) in self.columns.iter().enumerate() {
                let col = &self.stats[i];

                println!("Column: {}", name);
                println!("Type: {:?}", self.types[i]);
                println!("Count: {}", col.count);
                println!("Nulls: {}", col.nulls);
                println!("Unique: {}", col.unique_count());

                if let Some(mean) = col.mean() {
                    println!("Mean: {:.2}", mean);
                }
                if let Some(min) = col.min() {
                    println!("Min: {:.2}", min);
                }
                if let Some(max) = col.max() {
                    println!("Max: {:.2}", max);
                }

                println!("-----------------------------");
            }
        }
    }
}