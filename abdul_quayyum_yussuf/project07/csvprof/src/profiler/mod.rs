//! ColumnProfiler trait and implementations.
//!
//! This module defines the core trait-based abstraction for profiling different column types,
//! enabling extensibility without modifying main.rs.

pub mod integer;
pub mod float;
pub mod boolean;
pub mod date;
pub mod categorical;
pub mod text;

use crate::report::ColumnReport;
use crate::infer::InferredType;

/// Core trait for profiling a column incrementally.
///
/// Implements a streaming interface where values are fed one at a time,
/// and a final report is generated after all rows are processed.
pub trait ColumnProfiler: Send {
    /// Feed a single value to the profiler.
    ///
    /// # Arguments
    /// * `value` - An optional string value (None for null/empty)
    fn feed(&mut self, value: Option<&str>);

    /// Generate the final column report.
    fn report(&self) -> ColumnReport;
}

/// Factory function to create the appropriate profiler for an inferred type.
///
/// This enables adding new types by:
/// 1. Adding a new InferredType variant
/// 2. Creating a struct implementing ColumnProfiler
/// 3. Adding a match arm here
///
/// ...with no changes to main.rs or streaming logic.
pub fn create_profiler(
    column_name: String,
    inferred_type: InferredType,
    percentiles: bool,
    top_n: usize,
    histogram: bool,
) -> Box<dyn ColumnProfiler> {
    match inferred_type {
        InferredType::Integer => Box::new(integer::IntegerProfiler::new(
            column_name,
            percentiles,
        )),
        InferredType::Float => Box::new(float::FloatProfiler::new(
            column_name,
            percentiles,
        )),
        InferredType::Boolean => Box::new(boolean::BooleanProfiler::new(column_name)),
        InferredType::Date => Box::new(date::DateProfiler::new(column_name)),
        InferredType::Categorical => Box::new(categorical::CategoricalProfiler::new(
            column_name,
            top_n,
            histogram,
        )),
        InferredType::Text => Box::new(text::TextProfiler::new(column_name)),
    }
}
