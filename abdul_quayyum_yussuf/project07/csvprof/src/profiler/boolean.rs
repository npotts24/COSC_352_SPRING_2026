//! Boolean column profiler.

use super::ColumnProfiler;
use crate::report::{ColumnReport, CategoricalStats};
use std::collections::HashMap;

/// Profiles boolean columns with frequency statistics.
pub struct BooleanProfiler {
    name: String,
    row_count: usize,
    null_count: usize,
    frequencies: HashMap<String, usize>,
}

impl BooleanProfiler {
    /// Create a new boolean profiler.
    pub fn new(name: String) -> Self {
        Self {
            name,
            row_count: 0,
            null_count: 0,
            frequencies: HashMap::new(),
        }
    }
}

impl ColumnProfiler for BooleanProfiler {
    fn feed(&mut self, value: Option<&str>) {
        self.row_count += 1;

        match value {
            None => self.null_count += 1,
            Some(v) => {
                let normalized = normalize_boolean(v);
                *self.frequencies.entry(normalized).or_insert(0) += 1;
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

        let mut top_values: Vec<_> = self
            .frequencies
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        top_values.sort_by(|a, b| b.1.cmp(&a.1));

        let categorical_stats = Some(CategoricalStats {
            top_values: top_values.clone(),
            bottom_values: None,
            histogram: None,
        });

        ColumnReport {
            name: self.name.clone(),
            inferred_type: "Boolean".to_string(),
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

/// Normalize various boolean representations to a canonical form.
fn normalize_boolean(s: &str) -> String {
    let lower = s.to_lowercase();
    match lower.as_str() {
        "true" | "yes" | "y" | "1" => "true".to_string(),
        "false" | "no" | "n" | "0" => "false".to_string(),
        _ => lower,
    }
}
