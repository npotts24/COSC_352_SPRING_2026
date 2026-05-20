use crate::error::Result;
use csvprof::error::CsvProfError;
use std::collections::HashMap;

pub type Row = HashMap<String, String>;

pub struct StreamingLoader;

impl StreamingLoader {
    pub fn stream<F>(path: &str, mut on_row: F) -> Result<usize>
    where
        F: FnMut(Row) -> Result<()>,
    {
        let mut reader = csv::Reader::from_path(path).map_err(CsvProfError::Csv)?;
        let headers: Vec<String> = reader
            .headers()
            .map_err(CsvProfError::Csv)?
            .iter()
            .map(|s| s.to_string())
            .collect();

        let mut count = 0usize;
        for result in reader.records() {
            let record = result.map_err(CsvProfError::Csv)?;
            let row: Row = headers
                .iter()
                .cloned()
                .zip(record.iter().map(|s| s.to_string()))
                .collect();
            on_row(row)?;
            count += 1;
        }

        Ok(count)
    }

    pub fn load_columns(path: &str, columns: &[&str]) -> Result<Vec<Row>> {
        let mut rows = Vec::new();
        Self::stream(path, |row| {
            let filtered: Row = columns
                .iter()
                .filter_map(|&col| row.get(col).map(|v| (col.to_string(), v.clone())))
                .collect();
            rows.push(filtered);
            Ok(())
        })?;
        Ok(rows)
    }
}