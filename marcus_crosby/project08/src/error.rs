use thiserror::Error;

#[derive(Debug, Error)]
pub enum CsvProfError {
    #[error("invalid percentile `{0}`; expected a number in the inclusive range 0..=100")]
    InvalidPercentile(String),
    #[error("delimiter must be a single-byte character, got `{0}`")]
    InvalidDelimiter(char),
}
