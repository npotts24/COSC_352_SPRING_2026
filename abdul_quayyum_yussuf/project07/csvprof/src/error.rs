//! Custom error types for CSV profiling operations.

use thiserror::Error;

/// The main error type for CSV profiling operations.
#[derive(Error, Debug)]
#[allow(dead_code)]
pub enum CsvProfError {
    /// IO error during file operations.
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    /// CSV parsing error from the csv crate.
    #[error("CSV parse error: {0}")]
    Csv(#[from] csv::Error),

    /// Invalid or unsupported delimiter character.
    #[error("Invalid delimiter: {0}")]
    BadDelimiter(String),

    /// Error when no columns are found in the CSV.
    #[error("No columns found in CSV")]
    NoColumns,

    /// Error indicating an internal logic failure.
    #[error("Internal error: {0}")]
    Internal(String),
}
