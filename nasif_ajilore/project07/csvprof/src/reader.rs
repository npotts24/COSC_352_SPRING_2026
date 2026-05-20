/// Streaming CSV reader that processes rows without loading the entire file.
use std::io::{self, Read};
use std::path::Path;

use crate::error::{CsvProfError, Result};
use crate::stats::{ColumnAccumulator, Profiler};
use crate::types::ColumnProfile;

/// Read the CSV from `path` (or stdin if `"-"`) and profile every column.
///
/// Rows are streamed — only one row is in memory at a time (plus the
/// per-column accumulators).
pub fn profile_csv(
    path: &Path,
    delimiter: u8,
    has_header: bool,
    show_percentiles: bool,
    show_histogram: bool,
) -> Result<Vec<ColumnProfile>> {
    let reader: Box<dyn Read> = if path == Path::new("-") {
        Box::new(io::stdin().lock())
    } else {
        Box::new(std::fs::File::open(path)?)
    };

    let mut csv_reader = csv::ReaderBuilder::new()
        .delimiter(delimiter)
        .has_headers(has_header)
        .flexible(true)
        .from_reader(reader);

    // Determine column names.
    let headers: Vec<String> = if has_header {
        csv_reader
            .headers()?
            .iter()
            .map(|h| h.to_owned())
            .collect()
    } else {
        // We'll assign names after seeing the first record.
        Vec::new()
    };

    let mut accumulators: Vec<ColumnAccumulator> = Vec::new();
    let mut col_names: Vec<String> = headers;
    let mut first_record = true;

    for result in csv_reader.records() {
        let record = result?;

        // Lazily initialise accumulators on first data row.
        if first_record {
            let ncols = record.len();
            if ncols == 0 {
                return Err(CsvProfError::NoColumns);
            }
            if col_names.is_empty() {
                col_names = (0..ncols).map(|i| format!("col_{}", i)).collect();
            }
            accumulators = (0..ncols).map(|_| ColumnAccumulator::new()).collect();
            first_record = false;
        }

        for (i, field) in record.iter().enumerate() {
            if i < accumulators.len() {
                accumulators[i].push(field);
            }
        }
    }

    if accumulators.is_empty() {
        return Err(CsvProfError::NoRows);
    }

    // Finalise each column.
    let profiles: Vec<ColumnProfile> = accumulators
        .iter()
        .enumerate()
        .map(|(i, acc)| {
            let name = col_names.get(i).cloned().unwrap_or_else(|| format!("col_{}", i));
            acc.finish(&name, show_percentiles, show_histogram)
        })
        .collect();

    Ok(profiles)
}
