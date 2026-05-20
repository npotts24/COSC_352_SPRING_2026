use std::fs::File;
use std::io::{BufRead, BufReader};
use crate::error::CsvError;

pub struct CsvReader {
    headers: Vec<String>,
    lines: std::io::Lines<BufReader<File>>,
}

impl CsvReader {
    pub fn new(path: &str) -> Result<Self, CsvError> {
        let file = File::open(path)?;
        let mut reader = BufReader::new(file);

        let mut header_line = String::new();
        reader.read_line(&mut header_line)?;

        let headers = header_line
            .trim()
            .split(',')
            .map(|s| s.to_string())
            .collect();

        Ok(CsvReader {
            headers,
            lines: reader.lines(),
        })
    }

    pub fn headers(&self) -> &Vec<String> {
        &self.headers
    }

    pub fn next_row(&mut self) -> Option<Vec<String>> {
        self.lines.next().and_then(|line| {
            line.ok().map(|l| l.split(',').map(|s| s.to_string()).collect())
        })
    }
}