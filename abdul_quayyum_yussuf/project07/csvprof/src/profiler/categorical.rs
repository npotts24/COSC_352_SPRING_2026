//! Categorical column profiler.

use super::ColumnProfiler;
use crate::report::{ColumnReport, CategoricalStats};
use std::collections::HashMap;

/// Profiles categorical columns with frequency distribution.
pub struct CategoricalProfiler {
    name: String,
    row_count: usize,
    null_count: usize,
    frequencies: HashMap<String, usize>,
    top_n: usize,
    histogram: bool,
}

impl CategoricalProfiler {
    /// Create a new categorical profiler.
    pub fn new(name: String, top_n: usize, histogram: bool) -> Self {
        Self {
            name,
            row_count: 0,
            null_count: 0,
            frequencies: HashMap::new(),
            top_n,
            histogram,
        }
    }
}

impl ColumnProfiler for CategoricalProfiler {
    fn feed(&mut self, value: Option<&str>) {
        self.row_count += 1;

        match value {
            None => self.null_count += 1,
            Some(v) => {
                *self.frequencies.entry(v.to_string()).or_insert(0) += 1;
            }
        }
    }

    fn report(&self) -> ColumnReport {
        let unique_count = self.frequencies.len();
        let non_null_count = self.row_count - self.null_count;
        let null_pct = if self.row_count > 0 {
            (self.null_count as f64 / self.row_count as f64) * 100.0
        } else {
            0.0
        };

        let is_constant = non_null_count > 0 && unique_count == 1;

        // Sort by frequency
        let mut sorted: Vec<_> = self
            .frequencies
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        sorted.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));

        // Top N values
        let top_values: Vec<_> = sorted.iter().take(self.top_n).cloned().collect();

        // Bottom N values
        let bottom_values = if self.top_n > 0 && sorted.len() > self.top_n {
            let mut bottom: Vec<_> = sorted.iter().rev().take(self.top_n).cloned().collect();
            bottom.reverse();
            Some(bottom)
        } else {
            None
        };

        // Histogram data
        let histogram_data = if self.histogram {
            Some(sorted.iter().take(self.top_n).cloned().collect())
        } else {
            None
        };

        let categorical_stats = Some(CategoricalStats {
            top_values,
            bottom_values,
            histogram: histogram_data,
        });

        ColumnReport {
            name: self.name.clone(),
            inferred_type: "Categorical".to_string(),
            row_count: self.row_count,
            null_count: self.null_count,
            null_pct,
            unique_count,
            is_constant,
            mixed_type_warning: None,
            numeric_stats: None,
            categorical_stats,
            text_stats: None,
            date_stats: None,
        }
    }
}
