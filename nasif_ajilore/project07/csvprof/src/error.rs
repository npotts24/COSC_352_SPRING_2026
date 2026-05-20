/// Structured error types for csvprof using thiserror.
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CsvProfError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("CSV parsing error: {0}")]
    Csv(#[from] csv::Error),

    #[error("No columns found in CSV input")]
    NoColumns,

    #[error("No data rows found in CSV input")]
    NoRows,
}

pub type Result<T> = std::result::Result<T, CsvProfError>;
