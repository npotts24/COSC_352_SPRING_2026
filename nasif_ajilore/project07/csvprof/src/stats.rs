/// Per-column statistics accumulation using a trait-based design.
///
/// Each column gets a `ColumnAccumulator` that collects raw values in a
/// streaming fashion and then finalises into a `ColumnProfile`.
use std::collections::HashMap;

use crate::infer::{try_parse_date, TypeVoter};
use crate::types::*;

// ── Trait: Profiler ──────────────────────────────────────────────────────────

/// A `Profiler` can ingest string cell values one at a time and, once all rows
/// have been fed, produce a finished `ColumnProfile`.
pub trait Profiler {
    /// Feed a single cell value (raw string from the CSV).
    fn push(&mut self, value: &str);

    /// Finalise the accumulated data into a `ColumnProfile`.
    fn finish(&self, name: &str, show_percentiles: bool, show_histogram: bool) -> ColumnProfile;
}

// ── Concrete implementation ──────────────────────────────────────────────────

/// Accumulates raw data for one column. Implements `Profiler`.
pub struct ColumnAccumulator {
    voter: TypeVoter,
    /// Raw non-null string values kept for statistics after type resolution.
    raw_values: Vec<String>,
    null_count: usize,
    row_count: usize,
}

impl ColumnAccumulator {
    pub fn new() -> Self {
        Self {
            voter: TypeVoter::default(),
            raw_values: Vec::new(),
            null_count: 0,
            row_count: 0,
        }
    }
}

impl Profiler for ColumnAccumulator {
    fn push(&mut self, value: &str) {
        self.row_count += 1;
        let trimmed = value.trim();
        self.voter.vote(trimmed);

        if trimmed.is_empty() {
            self.null_count += 1;
        } else {
            self.raw_values.push(trimmed.to_owned());
        }
    }

    fn finish(&self, name: &str, show_percentiles: bool, show_histogram: bool) -> ColumnProfile {
        let (inferred, mixed) = self.voter.resolve();

        // Decide final type: low-cardinality text → Categorical.
        let unique: std::collections::HashSet<&str> =
            self.raw_values.iter().map(|s| s.as_str()).collect();
        let unique_count = unique.len();
        let non_null = self.raw_values.len();

        let final_type = if inferred == InferredType::Text && unique_count <= 50 && non_null > 0 {
            InferredType::Categorical
        } else {
            inferred
        };

        // Build type-specific stats.
        let numeric_stats = match final_type {
            InferredType::Integer | InferredType::Float => {
                compute_numeric_stats(&self.raw_values, show_percentiles)
            }
            _ => None,
        };

        let date_stats = if final_type == InferredType::Date {
            compute_date_stats(&self.raw_values)
        } else {
            None
        };

        let text_stats = if final_type == InferredType::Text {
            compute_text_stats(&self.raw_values)
        } else {
            None
        };

        let categorical_stats =
            if final_type == InferredType::Categorical || final_type == InferredType::Boolean {
                compute_categorical_stats(&self.raw_values, show_histogram)
            } else {
                None
            };

        // Quality flags.
        let null_pct = if self.row_count > 0 {
            self.null_count as f64 / self.row_count as f64
        } else {
            0.0
        };

        let outlier_count = numeric_stats.as_ref().and_then(|ns| {
            detect_outlier_count(&self.raw_values, ns)
        });

        let quality = QualityFlags {
            has_mixed_types: mixed,
            is_constant: unique_count <= 1,
            high_null_pct: null_pct > 0.5,
            outlier_count,
            low_cardinality: final_type != InferredType::Boolean
                && final_type != InferredType::Categorical
                && unique_count > 0
                && unique_count <= 5
                && non_null > 20,
        };

        ColumnProfile {
            name: name.to_owned(),
            inferred_type: final_type,
            row_count: self.row_count,
            null_count: self.null_count,
            unique_count,
            numeric_stats,
            date_stats,
            text_stats,
            categorical_stats,
            quality,
        }
    }
}

// ── Helper functions ─────────────────────────────────────────────────────────

fn compute_numeric_stats(values: &[String], show_percentiles: bool) -> Option<NumericStats> {
    let mut nums: Vec<f64> = values.iter().filter_map(|v| v.parse::<f64>().ok()).collect();
    if nums.is_empty() {
        return None;
    }
    nums.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

    let count = nums.len() as f64;
    let sum: f64 = nums.iter().sum();
    let mean = sum / count;
    let min = nums[0];
    let max = nums[nums.len() - 1];
    let median = percentile_sorted(&nums, 50.0);
    let variance: f64 = nums.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / count;
    let std_dev = variance.sqrt();

    let percentiles = if show_percentiles {
        Some(Percentiles {
            p5: percentile_sorted(&nums, 5.0),
            p25: percentile_sorted(&nums, 25.0),
            p75: percentile_sorted(&nums, 75.0),
            p95: percentile_sorted(&nums, 95.0),
        })
    } else {
        None
    };

    Some(NumericStats {
        min,
        max,
        mean,
        median,
        std_dev,
        percentiles,
    })
}

/// Linear interpolation percentile on a pre-sorted slice.
fn percentile_sorted(sorted: &[f64], pct: f64) -> f64 {
    if sorted.len() == 1 {
        return sorted[0];
    }
    let idx = (pct / 100.0) * (sorted.len() - 1) as f64;
    let lo = idx.floor() as usize;
    let hi = idx.ceil() as usize;
    let frac = idx - lo as f64;
    sorted[lo] * (1.0 - frac) + sorted[hi] * frac
}

fn compute_date_stats(values: &[String]) -> Option<DateStats> {
    let dates: Vec<chrono::NaiveDate> = values.iter().filter_map(|v| try_parse_date(v)).collect();
    if dates.is_empty() {
        return None;
    }
    let min = *dates.iter().min().unwrap();
    let max = *dates.iter().max().unwrap();
    Some(DateStats { min, max })
}

fn compute_text_stats(values: &[String]) -> Option<TextStats> {
    if values.is_empty() {
        return None;
    }
    let min_length = values.iter().map(|v| v.len()).min().unwrap_or(0);
    let max_length = values.iter().map(|v| v.len()).max().unwrap_or(0);
    Some(TextStats {
        min_length,
        max_length,
    })
}

fn compute_categorical_stats(values: &[String], show_histogram: bool) -> Option<CategoricalStats> {
    if values.is_empty() {
        return None;
    }
    let mut freq: HashMap<&str, usize> = HashMap::new();
    for v in values {
        *freq.entry(v.as_str()).or_insert(0) += 1;
    }
    let mut entries: Vec<FrequencyEntry> = freq
        .into_iter()
        .map(|(value, count)| FrequencyEntry {
            value: value.to_owned(),
            count,
        })
        .collect();

    // Sort descending by count for top-5 most frequent.
    entries.sort_by(|a, b| b.count.cmp(&a.count).then(a.value.cmp(&b.value)));
    let top_5_most: Vec<FrequencyEntry> = entries.iter().take(5).cloned().collect();

    // Sort ascending by count for top-5 least frequent.
    entries.sort_by(|a, b| a.count.cmp(&b.count).then(a.value.cmp(&b.value)));
    let top_5_least: Vec<FrequencyEntry> = entries.iter().take(5).cloned().collect();

    let histogram = if show_histogram {
        entries.sort_by(|a, b| b.count.cmp(&a.count).then(a.value.cmp(&b.value)));
        Some(entries)
    } else {
        None
    };

    Some(CategoricalStats {
        top_5_most,
        top_5_least,
        histogram,
    })
}

/// Detect outliers using the IQR method. Returns count of values outside
/// [Q1 - 1.5·IQR, Q3 + 1.5·IQR].
fn detect_outlier_count(values: &[String], stats: &NumericStats) -> Option<usize> {
    let mut nums: Vec<f64> = values.iter().filter_map(|v| v.parse::<f64>().ok()).collect();
    if nums.len() < 4 {
        return None;
    }
    nums.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let q1 = percentile_sorted(&nums, 25.0);
    let q3 = percentile_sorted(&nums, 75.0);
    let iqr = q3 - q1;
    let lower = q1 - 1.5 * iqr;
    let upper = q3 + 1.5 * iqr;
    let count = nums.iter().filter(|&&v| v < lower || v > upper).count();
    let _ = stats; // used indirectly via caller context
    Some(count)
}
