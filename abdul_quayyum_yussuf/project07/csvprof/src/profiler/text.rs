//! Text column profiler.

use super::ColumnProfiler;
use crate::report::{ColumnReport, TextStats};

/// Profiles text columns with string length statistics.
pub struct TextProfiler {
    name: String,
    row_count: usize,
    null_count: usize,
    min_length: usize,
    max_length: usize,
    total_length: usize,
    non_null_count: usize,
}

impl TextProfiler {
    /// Create a new text profiler.
    pub fn new(name: String) -> Self {
        Self {
            name,
            row_count: 0,
            null_count: 0,
            min_length: usize::MAX,
            max_length: 0,
            total_length: 0,
            non_null_count: 0,
        }
    }
}

impl ColumnProfiler for TextProfiler {
    fn feed(&mut self, value: Option<&str>) {
        self.row_count += 1;

        match value {
            None => self.null_count += 1,
            Some(v) => {
                let len = v.chars().count();
                self.total_length += len;
                self.non_null_count += 1;
                if len < self.min_length {
                    self.min_length = len;
                }
                if len > self.max_length {
                    self.max_length = len;
                }
            }
        }
    }

    fn report(&self) -> ColumnReport {
        let null_pct = if self.row_count > 0 {
            (self.null_count as f64 / self.row_count as f64) * 100.0
        } else {
            0.0
        };

        let avg_length = if self.non_null_count > 0 {
            self.total_length as f64 / self.non_null_count as f64
        } else {
            0.0
        };

        let min_length = if self.non_null_count > 0 {
            self.min_length
        } else {
            0
        };

        let text_stats = Some(TextStats {
            min_length,
            max_length: self.max_length,
            avg_length,
        });

        ColumnReport {
            name: self.name.clone(),
            inferred_type: "Text".to_string(),
            row_count: self.row_count,
            null_count: self.null_count,
            null_pct,
            unique_count: 0, // Text columns don't track unique values
            is_constant: false,
            mixed_type_warning: None,
            numeric_stats: None,
            categorical_stats: None,
            text_stats,
            date_stats: None,
        }
    }
}
