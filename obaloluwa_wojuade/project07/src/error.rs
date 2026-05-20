use thiserror::Error;

#[derive(Debug, Error)]
pub enum CsvProfError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
    #[error("CSV error: {0}")]
    Csv(#[from] csv::Error),
    #[error("Invalid file: {0}")]
    InvalidFile(String),
}

pub type Result<T> = std::result::Result<T, CsvProfError>;
