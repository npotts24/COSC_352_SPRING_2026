//! # csvprof
//!
//! A streaming CSV profiler and correlation library built around a small
//! set of traits. The crate exposes:
//!
//! - [`error::ProfileError`]  – a single `thiserror`-derived error type
//! - [`reader::StreamingCsvReader`] – row-at-a-time CSV ingestion
//! - [`analyzer::ColumnAnalyzer`]  – the extension point for column stats
//! - [`types::ColumnType`]        – the inference lattice
//! - [`profile::Profiler`]        – orchestrates reader + analyzers
//! - [`report::Report`]           – the serializable artifact you print
//!
//! Part 2 (`bin/baltimore.rs`) reuses every one of these; no logic is
//! duplicated.

pub mod analyzer;
pub mod error;
pub mod profile;
pub mod reader;
pub mod report;
pub mod types;

pub use analyzer::{ColumnAnalyzer, StandardAnalyzer};
pub use error::{ProfileError, Result};
pub use profile::Profiler;
pub use reader::StreamingCsvReader;
pub use report::{ColumnReport, Report};
pub use types::{ColumnType, InferredValue};
