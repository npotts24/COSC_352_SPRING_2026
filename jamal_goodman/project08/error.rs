use std::fmt;

#[derive(Debug)]
pub enum CsvError {
    Io(std::io::Error),
    MissingColumn(String),
}

impl From<std::io::Error> for CsvError {
    fn from(err: std::io::Error) -> Self {
        CsvError::Io(err)
    }
}

impl fmt::Display for CsvError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            CsvError::Io(e) => write!(f, "IO Error: {}", e),
            CsvError::MissingColumn(col) => write!(f, "Missing column: {}", col),
        }
    }
}