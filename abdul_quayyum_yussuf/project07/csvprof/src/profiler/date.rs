//! Date column profiler.

use super::ColumnProfiler;
use crate::report::{ColumnReport, DateStats};
use std::collections::HashSet;

/// Profiles date columns with temporal statistics.
pub struct DateProfiler {
    name: String,
    row_count: usize,
    null_count: usize,
    dates: Vec<String>,
    unique: HashSet<String>,
}

impl DateProfiler {
    /// Create a new date profiler.
    pub fn new(name: String) -> Self {
        Self {
            name,
            row_count: 0,
            null_count: 0,
            dates: Vec::new(),
            unique: HashSet::new(),
        }
    }
}

impl ColumnProfiler for DateProfiler {
    fn feed(&mut self, value: Option<&str>) {
        self.row_count += 1;

        match value {
            None => self.null_count += 1,
            Some(v) => {
                self.dates.push(v.to_string());
                self.unique.insert(v.to_string());
            }
        }
    }

    fn report(&self) -> ColumnReport {
        let unique_count = self.unique.len();
        let non_null_count = self.row_count - self.null_count;
        let null_pct = if self.row_count > 0 {
            (self.null_count as f64 / self.row_count as f64) * 100.0
        } else {
            0.0
        };

        let is_constant = non_null_count > 0 && unique_count == 1;

        // Find min and max dates (lexicographic order for simplicity)
        let mut sorted_dates = self.dates.clone();
        sorted_dates.sort();
        sorted_dates.dedup();

        let (min_date, max_date) = if !sorted_dates.is_empty() {
            (
                Some(sorted_dates[0].clone()),
                Some(sorted_dates[sorted_dates.len() - 1].clone()),
            )
        } else {
            (None, None)
        };

        let date_stats = Some(DateStats {
            min_date,
            max_date,
            unique_count,
        });

        ColumnReport {
            name: self.name.clone(),
            inferred_type: "Date".to_string(),
            row_count: self.row_count,
            null_count: self.null_count,
            null_pct,
            unique_count,
            is_constant,
            mixed_type_warning: None,
            numeric_stats: None,
            categorical_stats: None,
            text_stats: None,
            date_stats,
        }
    }
}
