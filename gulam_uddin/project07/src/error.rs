use thiserror::Error;

/// Unified error type for the profiling pipeline.
#[derive(Error, Debug)]
pub enum ProfilingError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("CSV parsing error: {0}")]
    Csv(#[from] csv::Error),

    #[error("JSON serialization error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Input file not found: {path}")]
    FileNotFound { path: String },

    #[error("CSV file contains no columns")]
    EmptyFile,

    #[error("{0}")]
    Other(String),
}