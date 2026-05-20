use thiserror::Error;

#[derive(Debug, Error)]
pub enum AnalysisError {
    #[error("csvprof error: {0}")]
    Prof(#[from] csvprof::error::CsvProfError),
    #[error("analysis error: {0}")]
    Analysis(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

pub type Result<T> = std::result::Result<T, AnalysisError>;