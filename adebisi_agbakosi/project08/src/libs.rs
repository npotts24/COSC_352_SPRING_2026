use anyhow::Result;
use std::fs::File;
use csv::Reader;

pub trait ColumnAnalyzer {
    fn update(&mut self, value: &str);
    fn report(&self) -> String;
}

pub struct StatsAnalyzer {
    pub count: usize,
}

impl StatsAnalyzer {
    pub fn new() -> Self { Self { count: 0 } }
}

impl ColumnAnalyzer for StatsAnalyzer {
    fn update(&mut self, _value: &str) { self.count += 1; }
    fn report(&self) -> String { format!("Count: {}", self.count) }
}