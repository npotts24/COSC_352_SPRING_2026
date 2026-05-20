//! Top-level orchestrator.
//!
//! [`Profiler`] glues [`StreamingCsvReader`] to a vector of
//! [`ColumnAnalyzer`]s — one per column. The analyzer type is pluggable
//! via a factory closure so Part 2 (or any downstream user) can swap in
//! custom logic without forking this crate.

use std::io::Read;

use crate::analyzer::{AnalyzerOptions, ColumnAnalyzer, StandardAnalyzer};
use crate::error::Result;
use crate::reader::StreamingCsvReader;
use crate::report::Report;

/// Factory signature: given a column name and its index, produce a fresh
/// analyzer for that column. Different columns can, in principle, get
/// different analyzers — useful when the user knows schema in advance.
pub type AnalyzerFactory =
    Box<dyn Fn(&str, usize) -> Box<dyn ColumnAnalyzer>>;

/// The orchestrator.
pub struct Profiler {
    source_label: String,
    factory:      AnalyzerFactory,
}

impl Profiler {
    /// New profiler that uses [`StandardAnalyzer`] with default options
    /// for every column.
    pub fn new(source_label: impl Into<String>) -> Self {
        Self::with_options(source_label, AnalyzerOptions::default())
    }

    /// Use standard analyzer everywhere, but with custom options.
    pub fn with_options(
        source_label: impl Into<String>,
        opts: AnalyzerOptions,
    ) -> Self {
        let f: AnalyzerFactory = Box::new(move |_name, _ix| {
            Box::new(StandardAnalyzer::new(opts))
        });
        Self { source_label: source_label.into(), factory: f }
    }

    /// Fully custom factory — useful for tests and for Part 2.
    pub fn with_analyzer_factory(
        source_label: impl Into<String>,
        factory: AnalyzerFactory,
    ) -> Self {
        Self { source_label: source_label.into(), factory }
    }

    /// Drive the reader to completion and return the report.
    pub fn run<R: Read>(
        self,
        reader: &mut StreamingCsvReader<R>,
    ) -> Result<Report> {
        let headers: Vec<String> = reader.headers().to_vec();

        // One analyzer per column.
        let mut analyzers: Vec<Box<dyn ColumnAnalyzer>> = headers
            .iter()
            .enumerate()
            .map(|(ix, name)| (self.factory)(name, ix))
            .collect();

        let rows = reader.for_each_record(|_i, record| {
            // record.iter() yields &str by reference — no cloning.
            for (ix, cell) in record.iter().enumerate() {
                if let Some(a) = analyzers.get_mut(ix) {
                    a.observe(cell);
                }
            }
            Ok(())
        })?;

        let columns = analyzers
            .into_iter()
            .zip(headers.into_iter())
            .map(|(a, name)| a.finalize(name))
            .collect();

        Ok(Report {
            source:  self.source_label,
            rows,
            columns,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn end_to_end_small_csv() {
        let data = "\
name,age,city
Alice,30,NYC
Bob,25,LA
Carol,,NYC
";
        let mut r = StreamingCsvReader::from_reader(data.as_bytes()).unwrap();
        let p = Profiler::new("memory");
        let report = p.run(&mut r).unwrap();
        assert_eq!(report.rows, 3);
        assert_eq!(report.columns.len(), 3);
        // name column is text and low-cardinality → Categorical
        assert_eq!(
            report.columns.iter().find(|c| c.name == "name").unwrap().inferred,
            crate::types::ColumnType::Categorical
        );
        // age column has one null
        let age = report.columns.iter().find(|c| c.name == "age").unwrap();
        assert_eq!(age.null_count, 1);
        assert_eq!(age.inferred, crate::types::ColumnType::Integer);
    }
}
