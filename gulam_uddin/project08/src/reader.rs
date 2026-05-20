//! Streaming CSV reader.
//!
//! Wraps `csv::Reader` so that the rest of the crate works against our
//! own error type rather than `csv::Error` directly. Rows are yielded
//! **one at a time** — we never materialise the whole file in memory.
//!
//! The reader accepts either a filesystem path or stdin (`"-"`), so
//! the tool can sit in a Unix pipeline.

use crate::error::{ProfileError, Result};
use csv::{Reader, ReaderBuilder, StringRecord};
use std::fs::File;
use std::io::{self, BufReader, Read};
use std::path::Path;

/// A streaming reader that owns the headers and yields records lazily.
pub struct StreamingCsvReader<R: Read> {
    inner:   Reader<R>,
    headers: Vec<String>,
}

impl StreamingCsvReader<Box<dyn Read>> {
    /// Open a path. Use `-` to read from stdin.
    pub fn open(path: &str) -> Result<Self> {
        let reader: Box<dyn Read> = if path == "-" {
            Box::new(io::stdin().lock())
        } else {
            let p = Path::new(path);
            if !p.exists() {
                return Err(ProfileError::InvalidConfig(format!(
                    "file not found: {}",
                    path
                )));
            }
            Box::new(BufReader::new(File::open(p)?))
        };
        Self::from_reader(reader)
    }
}

impl<R: Read> StreamingCsvReader<R> {
    /// Construct from any `Read`; useful for tests.
    pub fn from_reader(rdr: R) -> Result<Self> {
        let mut inner = ReaderBuilder::new()
            .has_headers(true)
            .flexible(true)      // tolerate ragged rows
            .trim(csv::Trim::None)
            .from_reader(rdr);

        let headers = inner
            .headers()
            .map_err(ProfileError::from)?
            .iter()
            .map(|s| s.to_owned())
            .collect::<Vec<_>>();

        if headers.is_empty() {
            return Err(ProfileError::EmptyInput);
        }
        Ok(Self { inner, headers })
    }

    /// Borrow the header row.
    pub fn headers(&self) -> &[String] {
        &self.headers
    }

    /// Visit every record by reference, without allocating a Vec per row.
    ///
    /// The closure gets `(row_index, &StringRecord)` so implementations
    /// can skip cloning the cells when they don't need to keep them.
    pub fn for_each_record<F>(&mut self, mut f: F) -> Result<usize>
    where
        F: FnMut(usize, &StringRecord) -> Result<()>,
    {
        let mut record = StringRecord::new();
        let mut i = 0;
        while self.inner.read_record(&mut record)? {
            f(i, &record)?;
            i += 1;
        }
        Ok(i)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn read_basic_csv() {
        let data = "a,b,c\n1,2,3\n4,5,6\n";
        let mut r = StreamingCsvReader::from_reader(data.as_bytes()).unwrap();
        assert_eq!(r.headers(), &["a", "b", "c"]);

        let mut seen = 0;
        let total = r.for_each_record(|_, rec| {
            assert_eq!(rec.len(), 3);
            seen += 1;
            Ok(())
        }).unwrap();
        assert_eq!(total, 2);
        assert_eq!(seen, 2);
    }

    #[test]
    fn empty_file_errors() {
        let data = "";
        let err = StreamingCsvReader::from_reader(data.as_bytes()).err();
        assert!(err.is_some());
    }
}
