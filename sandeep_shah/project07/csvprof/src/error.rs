use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("failed to open input '{path}': {source}")]
    OpenInput {
        path: String,
        #[source]
        source: std::io::Error,
    },

    #[error("CSV error: {0}")]
    Csv(#[from] csv::Error),
}
