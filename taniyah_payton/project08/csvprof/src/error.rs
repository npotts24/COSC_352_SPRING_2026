use thiserror::Error;

#[derive(Error, Debug)]
pub enum ProfilerError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("CSV parse error: {0}")]
    Csv(#[from] csv::Error),

    #[error("File not found: {path}")]
    FileNotFound { path: String },

    #[error("Empty CSV file — no rows to profile")]
    EmptyFile,

    #[error("No columns found in CSV")]
    NoColumns,

    #[error("JSON serialization error: {0}")]
    Json(#[from] serde_json::Error),
}
