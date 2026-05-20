//! csvprof reusable library for CSV profiling.
//!
//! This crate exposes the same inference and profiling logic used by the `csvprof`
//! binary, making it available to other projects without duplicating the core
//! streaming reader, trait-based profiler, or error handling.

pub mod cli;
pub mod error;
pub mod infer;
pub mod output;
pub mod profiler;
pub mod report;

use csv::ReaderBuilder;
use std::fs::File;
use std::io::Read;

pub use crate::error::CsvProfError;
pub use crate::infer::{InferredType, TypeInferrer};
pub use crate::profiler::{create_profiler, ColumnProfiler};
pub use crate::report::{ColumnReport, CsvReport};

/// Configuration for profiling operations.
pub struct ProfileConfig {
    pub delimiter: u8,
    pub no_header: bool,
    pub max_unique: usize,
    pub percentiles: bool,
    pub top_n: usize,
    pub hist: bool,
}

/// Read input from file or stdin into a string buffer.
pub fn read_input(file_path: &str) -> Result<String, CsvProfError> {
    let mut content = String::new();
    if file_path == "-" {
        std::io::stdin().read_to_string(&mut content)?;
    } else {
        let mut file = File::open(file_path)?;
        file.read_to_string(&mut content)?;
    }
    Ok(content)
}

/// Infer column types from CSV content using a sampling pass.
pub fn infer_column_types(
    content: &str,
    config: &ProfileConfig,
) -> Result<(Vec<String>, Vec<InferredType>), CsvProfError> {
    let mut reader = ReaderBuilder::new()
        .delimiter(config.delimiter)
        .has_headers(!config.no_header)
        .from_reader(content.as_bytes());

    let mut headers = Vec::new();
    let mut sample_rows = Vec::new();
    let sample_size = 1000;

    if !config.no_header {
        if let Ok(record) = reader.headers() {
            headers = record.iter().map(|s| s.to_string()).collect();
        }
    }

    for (i, result) in reader.records().enumerate() {
        if i >= sample_size {
            break;
        }
        let record = result?;
        sample_rows.push(record.iter().map(|s| s.to_string()).collect::<Vec<_>>());
    }

    if headers.is_empty() && !sample_rows.is_empty() {
        headers = (0..sample_rows[0].len())
            .map(|i| format!("Column_{}", i))
            .collect();
    }

    let inferrer = TypeInferrer::new(config.max_unique, sample_size);
    let inferred_types = if !sample_rows.is_empty() {
        (0..headers.len())
            .map(|col_idx| {
                let values: Vec<&str> = sample_rows
                    .iter()
                    .filter_map(|row| {
                        row.get(col_idx)
                            .map(|s| s.as_str())
                            .filter(|s| !s.is_empty())
                    })
                    .collect();
                inferrer.infer(&values)
            })
            .collect()
    } else {
        vec![InferredType::Text; headers.len()]
    };

    Ok((headers, inferred_types))
}

/// Profile all columns in the CSV content using the inferred types.
pub fn profile_columns(
    content: &str,
    headers: &[String],
    inferred_types: &[InferredType],
    config: &ProfileConfig,
) -> Result<Vec<ColumnReport>, CsvProfError> {
    let mut reader = ReaderBuilder::new()
        .delimiter(config.delimiter)
        .has_headers(!config.no_header)
        .from_reader(content.as_bytes());

    let mut profilers: Vec<Box<dyn ColumnProfiler>> = headers
        .iter()
        .enumerate()
        .map(|(i, name)| {
            create_profiler(
                name.clone(),
                inferred_types[i],
                config.percentiles,
                config.top_n,
                config.hist,
            )
        })
        .collect();

    for result in reader.records() {
        let record = result?;
        for i in 0..headers.len() {
            let value = record.get(i).and_then(|s| if s.is_empty() { None } else { Some(s) });
            profilers[i].feed(value);
        }
    }

    Ok(profilers.into_iter().map(|profiler| profiler.report()).collect())
}

/// Profile CSV content and produce a full `CsvReport`.
pub fn profile_csv_content(
    content: &str,
    input_desc: String,
    config: &ProfileConfig,
) -> Result<CsvReport, CsvProfError> {
    let (headers, inferred_types) = infer_column_types(content, config)?;
    let column_reports = profile_columns(content, &headers, &inferred_types, config)?;

    let rows = column_reports.first().map(|r| r.row_count).unwrap_or(0);
    Ok(CsvReport {
        file: input_desc,
        rows,
        columns: headers.len(),
        column_reports,
    })
}
