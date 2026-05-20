use thiserror::Error;

#[derive(Debug, Error)]
pub enum CsvProfError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("CSV parse error: {0}")]
    Csv(#[from] csv::Error),

    #[error("Serialization error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("No columns found in CSV file")]
    NoColumns,

    #[error("File not found: {0}")]
    FileNotFound(String),
}
