/// Public library interface for csvprof.
///
/// Exposes the core traits, types, reader, and error types so that downstream
/// crates (e.g. the Part 2 Baltimore City Open Data analysis tool) can reuse
/// the streaming CSV reader, the `Profiler` trait, and `CsvProfError` without
/// duplicating any logic.
pub mod cli;
pub mod error;
pub mod infer;
pub mod reader;
pub mod report;
pub mod stats;
pub mod types;
