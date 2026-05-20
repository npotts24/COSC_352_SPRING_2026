use std::io::Read;

use crate::error::ProfilerError;

/// Streams the CSV and accumulates per-column raw string values.
/// Memory usage is O(rows × columns) for the accumulated strings, but
/// we never hold the full CSV bytes — records are discarded as we go.
pub struct CsvIngestor;

pub struct IngestedData {
    pub headers: Vec<String>,
    /// column_values[i] = all raw string values for column i (including nulls)
    pub column_values: Vec<Vec<String>>,
}

impl CsvIngestor {
    /// Read from any `Read` source; builds column-oriented storage row by row.
    pub fn ingest<R: Read>(reader: R) -> Result<IngestedData, ProfilerError> {
        let mut rdr = csv::ReaderBuilder::new()
            .has_headers(true)
            .flexible(true) // tolerate ragged rows
            .trim(csv::Trim::Fields)
            .from_reader(reader);

        let headers: Vec<String> = rdr
            .headers()?
            .iter()
            .map(|h| h.to_string())
            .collect();

        if headers.is_empty() {
            return Err(ProfilerError::NoColumns);
        }

        let ncols = headers.len();
        let mut column_values: Vec<Vec<String>> = vec![Vec::new(); ncols];

        for result in rdr.records() {
            let record = result?;
            for (i, field) in record.iter().enumerate() {
                if i < ncols {
                    column_values[i].push(field.to_string());
                }
            }
            // Ragged rows: pad missing columns with empty string
            for i in record.len()..ncols {
                column_values[i].push(String::new());
            }
        }

        if column_values[0].is_empty() {
            return Err(ProfilerError::EmptyFile);
        }

        Ok(IngestedData {
            headers,
            column_values,
        })
    }
}
