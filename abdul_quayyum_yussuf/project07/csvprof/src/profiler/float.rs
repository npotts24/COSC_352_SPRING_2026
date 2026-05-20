//! Float column profiler.

use super::ColumnProfiler;
use crate::report::{ColumnReport, NumericStats};
use std::collections::HashSet;

/// Profiles floating-point columns with numeric statistics.
pub struct FloatProfiler {
    name: String,
    row_count: usize,
    null_count: usize,
    values: Vec<f64>,
    unique: HashSet<ordered_float::OrderedFloat<f64>>,
    percentiles: bool,
    has_mixed_types: bool,
}

impl FloatProfiler {
    /// Create a new float profiler.
    pub fn new(name: String, percentiles: bool) -> Self {
        Self {
            name,
            row_count: 0,
            null_count: 0,
            values: Vec::new(),
            unique: HashSet::new(),
            percentiles,
            has_mixed_types: false,
        }
    }
}

impl ColumnProfiler for FloatProfiler {
    fn feed(&mut self, value: Option<&str>) {
        self.row_count += 1;

        match value {
            None => self.null_count += 1,
            Some(v) => {
                if let Ok(f) = v.parse::<f64>() {
                    self.values.push(f);
                    self.unique.insert(ordered_float::OrderedFloat(f));
                } else {
                    self.has_mixed_types = true;
                }
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

        let mixed_type_warning = if self.has_mixed_types {
            Some("Column contains values that cannot be parsed as floats".to_string())
        } else {
            None
        };

        let numeric_stats = if !self.values.is_empty() {
            Some(compute_numeric_stats(&self.values, self.percentiles))
        } else {
            None
        };

        ColumnReport {
            name: self.name.clone(),
            inferred_type: "Float".to_string(),
            row_count: self.row_count,
            null_count: self.null_count,
            null_pct,
            unique_count,
            is_constant,
            mixed_type_warning,
            numeric_stats,
            categorical_stats: None,
            text_stats: None,
            date_stats: None,
        }
    }
}

/// Compute numeric statistics using Welford's algorithm for mean/variance.
fn compute_numeric_stats(values: &[f64], percentiles: bool) -> NumericStats {
    if values.is_empty() {
        return NumericStats {
            min: 0.0,
            max: 0.0,
            mean: 0.0,
            median: 0.0,
            std_dev: 0.0,
            p5: None,
            p25: None,
            p75: None,
            p95: None,
        };
    }

    // Find min/max
    let mut min = f64::INFINITY;
    let mut max = f64::NEG_INFINITY;
    for &v in values {
        if v < min && !v.is_nan() {
            min = v;
        }
        if v > max && !v.is_nan() {
            max = v;
        }
    }

    // Welford's online algorithm for mean and variance
    let mut mean = 0.0;
    let mut m2 = 0.0;
    let mut count = 0;
    for &v in values {
        if !v.is_nan() {
            count += 1;
            let delta = v - mean;
            mean += delta / count as f64;
            let delta2 = v - mean;
            m2 += delta * delta2;
        }
    }

    let variance = if count > 1 {
        m2 / (count - 1) as f64
    } else {
        m2
    };
    let std_dev = variance.sqrt();

    // Median
    let valid_values: Vec<f64> = values.iter().filter(|v| !v.is_nan()).copied().collect();
    let median = if valid_values.is_empty() {
        0.0
    } else {
        let mut sorted = valid_values.clone();
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        if sorted.len().is_multiple_of(2) {
            (sorted[sorted.len() / 2 - 1] + sorted[sorted.len() / 2]) / 2.0
        } else {
            sorted[sorted.len() / 2]
        }
    };

    // Percentiles
    let (p5, p25, p75, p95) = if percentiles && !valid_values.is_empty() {
        let mut sorted = valid_values;
        sorted.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        (
            Some(percentile(&sorted, 5.0)),
            Some(percentile(&sorted, 25.0)),
            Some(percentile(&sorted, 75.0)),
            Some(percentile(&sorted, 95.0)),
        )
    } else {
        (None, None, None, None)
    };

    NumericStats {
        min,
        max,
        mean,
        median,
        std_dev,
        p5,
        p25,
        p75,
        p95,
    }
}

/// Compute a percentile value.
fn percentile(sorted: &[f64], p: f64) -> f64 {
    if sorted.is_empty() {
        return 0.0;
    }
    let idx = (p / 100.0) * (sorted.len() as f64);
    let lower = idx.floor() as usize;
    let upper = idx.ceil() as usize;

    if lower == upper || lower >= sorted.len() {
        sorted[lower.min(sorted.len() - 1)]
    } else {
        let fraction = idx - lower as f64;
        sorted[lower] * (1.0 - fraction) + sorted[upper.min(sorted.len() - 1)] * fraction
    }
}
