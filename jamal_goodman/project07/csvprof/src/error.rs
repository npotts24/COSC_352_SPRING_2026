use thiserror::Error;

#[derive(Error, Debug)]
pub enum CsvProfError {
    #[error("CSV error: {0}")]
    Csv(#[from] csv::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}