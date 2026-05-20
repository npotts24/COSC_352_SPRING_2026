//! Structured error type for the entire crate.
//!
//! We expose one error enum and a `Result<T>` alias. Every fallible path
//! in the crate (CSV I/O, JSON serialization, bad command-line input,
//! missing columns, etc.) lands here with a helpful message.

use std::io;
use thiserror::Error;

/// The single error type used throughout `csvprof`.
#[derive(Debug, Error)]
pub enum ProfileError {
    #[error("I/O error: {0}")]
    Io(#[from] io::Error),

    #[error("CSV parse error: {0}")]
    Csv(#[from] csv::Error),

    #[error("JSON serialization error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Column `{0}` not found in CSV header")]
    ColumnNotFound(String),

    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("Empty input: CSV file has no header row")]
    EmptyInput,

    #[error("{0}")]
    Other(String),
}

/// Convenience alias.
pub type Result<T> = std::result::Result<T, ProfileError>;
