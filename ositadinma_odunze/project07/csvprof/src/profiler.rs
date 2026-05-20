//! Orchestrates the streaming CSV read and per-column accumulation.

use std::io::Read;

use anyhow::Result;

use crate::{
    accumulator::{AccumulatorConfig, ColumnAccumulator},
    error::CsvProfError,
    types::FileProfile,
};

/// Profile a CSV file (or stdin) using a streaming reader.
pub fn profile<R: Read>(
    reader: R,
    file_label: &str,
    cfg: AccumulatorConfig,
) -> Result<FileProfile> {
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .flexible(true)          // tolerate ragged rows
        .trim(csv::Trim::All)
        .from_reader(reader);

    // ── read header 
    let headers: Vec<String> = {
        let h = rdr.headers().map_err(CsvProfError::Csv)?;
        if h.is_empty() {
            return Err(CsvProfError::NoColumns.into());
        }
        h.iter().map(|s| s.to_owned()).collect()
    };

    let ncols = headers.len();
    let mut accumulators: Vec<ColumnAccumulator> = headers
        .iter()
        .map(|h| ColumnAccumulator::new(h, cfg.max_categories))
        .collect();

    // ── stream rows 
    let mut total_rows: u64 = 0;
    let mut record = csv::StringRecord::new();

    while rdr.read_record(&mut record).map_err(CsvProfError::Csv)? {
        total_rows += 1;
        for (i, acc) in accumulators.iter_mut().enumerate() {
            let cell = record.get(i);
            let value = cell.and_then(|s| {
                let t = s.trim();
                if t.is_empty() { None } else { Some(t) }
            });
            acc.feed(value);
        }
    }

    // ── finalize 
    let columns = accumulators
        .into_iter()
        .map(|acc| acc.finalize(&cfg))
        .collect();

    Ok(FileProfile {
        file: file_label.to_owned(),
        total_rows,
        total_cols: ncols,
        columns,
    })
}
