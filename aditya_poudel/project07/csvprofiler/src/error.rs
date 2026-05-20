use thiserror::Error;

#[derive(Debug, Error)]
pub enum ProfileError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("CSV parsing error: {0}")]
    Csv(#[from] csv::Error),

    #[error("File not found: {path}")]
    FileNotFound { path: String },

    #[error("Empty CSV file (no headers found)")]
    EmptyFile,

    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, ProfileError>;