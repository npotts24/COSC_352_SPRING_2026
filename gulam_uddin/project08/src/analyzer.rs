//! Column analyzers.
//!
//! [`ColumnAnalyzer`] is the extension point for computing per-column
//! statistics. The default [`StandardAnalyzer`] handles every spec'd
//! case (nulls, unique counts, numeric stats, percentiles, top-K,
//! string lengths, mixed/constant detection). To support a new kind
//! of column statistic, implement `ColumnAnalyzer` and plug it into
//! [`crate::profile::Profiler::with_analyzer_factory`].

use std::collections::HashMap;

use crate::report::{ColumnReport, NumericStats, TopK};
use crate::types::{unify, ColumnType, InferredValue};

/// The trait Part 2 reuses to compute per-column statistics.
///
/// The contract is **push-based**: the orchestrator calls [`observe`]
/// once per row, then [`finalize`] once at the end. Implementations
/// must be cheap to construct (one per column) and bounded in memory
/// relative to cardinality, not total row count.
pub trait ColumnAnalyzer {
    /// Observe one raw cell from this column.
    fn observe(&mut self, raw: &str);

    /// Consume the analyzer and produce the final report row.
    fn finalize(self: Box<Self>, column_name: String) -> ColumnReport;
}

/// Knobs that change which optional fields `StandardAnalyzer` emits.
#[derive(Debug, Clone, Copy)]
pub struct AnalyzerOptions {
    /// Emit p5/p25/p75/p95 for numeric columns.
    pub percentiles: bool,
    /// Emit full value-frequency histogram for categorical columns.
    pub histogram: bool,
    /// Max cardinality for promoting `Text` -> `Categorical`.
    pub categorical_threshold: usize,
    /// Cap on how many distinct string values we track per column, to
    /// keep memory bounded on pathologically wide text columns.
    pub distinct_cap: usize,
}

impl Default for AnalyzerOptions {
    fn default() -> Self {
        Self {
            percentiles: false,
            histogram: false,
            categorical_threshold: 32,
            distinct_cap: 100_000,
        }
    }
}

/// The default, fully-featured analyzer.
///
/// This struct is deliberately *one* implementation; its internals are
/// private. Custom analyzers should implement [`ColumnAnalyzer`] directly
/// rather than extending this one.
pub struct StandardAnalyzer {
    opts: AnalyzerOptions,

    // Running state
    seen: usize,
    nulls: usize,
    inferred: ColumnType,
    had_conflict: bool,

    // Numeric
    numerics: Vec<f64>, // retained so we can compute median / percentiles

    // Dates — track min/max only, don't store all values.
    date_min: Option<chrono::NaiveDate>,
    date_max: Option<chrono::NaiveDate>,

    // String lengths for text columns
    min_len: Option<usize>,
    max_len: Option<usize>,

    // Value frequency (bounded by `distinct_cap`)
    freq: HashMap<String, usize>,
    freq_saturated: bool,
}

impl StandardAnalyzer {
    pub fn new(opts: AnalyzerOptions) -> Self {
        Self {
            opts,
            seen: 0,
            nulls: 0,
            inferred: ColumnType::Empty,
            had_conflict: false,
            numerics: Vec::new(),
            date_min: None,
            date_max: None,
            min_len: None,
            max_len: None,
            freq: HashMap::new(),
            freq_saturated: false,
        }
    }

    fn record_freq(&mut self, s: &str) {
        if self.freq_saturated {
            return;
        }
        if self.freq.len() >= self.opts.distinct_cap && !self.freq.contains_key(s) {
            self.freq_saturated = true;
            return;
        }
        *self.freq.entry(s.to_owned()).or_insert(0) += 1;
    }
}

impl ColumnAnalyzer for StandardAnalyzer {
    fn observe(&mut self, raw: &str) {
        self.seen += 1;

        let value = InferredValue::parse(raw);
        let implied = value.implied_type();
        let before = self.inferred;
        let after = unify(before, implied);
        // Flag mixed types whenever we transition *into* Text from a
        // typed (non-Empty, non-Text) state. That covers:
        //   * int → text ("hello" appearing in a numeric column)
        //   * int → float → text cascades
        //   * date → int → text, etc.
        // and skips the harmless first-observation case.
        let drifted_to_text = after == ColumnType::Text
            && before != ColumnType::Empty
            && before != ColumnType::Text;
        let direct_conflict = before != ColumnType::Empty
            && implied != ColumnType::Empty
            && before != implied
            && !matches!((before, implied),
                (ColumnType::Integer, ColumnType::Float) |
                (ColumnType::Float,   ColumnType::Integer));
        if drifted_to_text || direct_conflict {
            self.had_conflict = true;
        }
        self.inferred = after;

        match value {
            InferredValue::Null => {
                self.nulls += 1;
            }
            InferredValue::Bool(b) => {
                self.record_freq(if b { "true" } else { "false" });
            }
            InferredValue::Int(n) => {
                self.numerics.push(n as f64);
                self.record_freq(raw.trim());
            }
            InferredValue::Float(f) => {
                self.numerics.push(f);
                self.record_freq(raw.trim());
            }
            InferredValue::Date(d) => {
                self.date_min = Some(self.date_min.map_or(d, |m| m.min(d)));
                self.date_max = Some(self.date_max.map_or(d, |m| m.max(d)));
                self.record_freq(raw.trim());
            }
            InferredValue::Text(s) => {
                let len = s.chars().count();
                self.min_len = Some(self.min_len.map_or(len, |m| m.min(len)));
                self.max_len = Some(self.max_len.map_or(len, |m| m.max(len)));
                self.record_freq(&s);
            }
        }
    }

    fn finalize(self: Box<Self>, column_name: String) -> ColumnReport {
        let Self {
            opts,
            seen,
            nulls,
            inferred,
            had_conflict,
            mut numerics,
            date_min,
            date_max,
            min_len,
            max_len,
            freq,
            freq_saturated,
        } = *self;

        // Promote low-cardinality Text -> Categorical
        let mut final_type = inferred;
        if final_type == ColumnType::Text
            && !freq_saturated
            && freq.len() <= opts.categorical_threshold
            && freq.len() > 1
        {
            final_type = ColumnType::Categorical;
        }

        let unique = if freq_saturated { None } else { Some(freq.len()) };
        let non_null = seen - nulls;
        let null_pct = if seen == 0 { 0.0 }
                       else { (nulls as f64) * 100.0 / (seen as f64) };

        // Numeric stats
        let numeric_stats = if final_type.is_numeric() && !numerics.is_empty() {
            numerics.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
            let n = numerics.len();
            let sum: f64 = numerics.iter().sum();
            let mean = sum / n as f64;
            let median = percentile(&numerics, 50.0);
            let var = numerics.iter().map(|v| (v - mean).powi(2)).sum::<f64>() / n as f64;
            let std = var.sqrt();
            let min = numerics[0];
            let max = numerics[n - 1];
            let pct = if opts.percentiles {
                Some([
                    percentile(&numerics, 5.0),
                    percentile(&numerics, 25.0),
                    percentile(&numerics, 75.0),
                    percentile(&numerics, 95.0),
                ])
            } else {
                None
            };
            // Simple 1.5*IQR outlier count
            let q1 = percentile(&numerics, 25.0);
            let q3 = percentile(&numerics, 75.0);
            let iqr = q3 - q1;
            let lo  = q1 - 1.5 * iqr;
            let hi  = q3 + 1.5 * iqr;
            let outliers = numerics.iter().filter(|v| **v < lo || **v > hi).count();

            Some(NumericStats {
                min, max, mean, median, std_dev: std,
                percentiles: pct, outlier_count: outliers,
            })
        } else {
            None
        };

        // Date range
        let date_range = date_min.zip(date_max).map(|(a, b)| (a.to_string(), b.to_string()));

        // Top-K / histogram
        let top_k = if matches!(final_type, ColumnType::Categorical | ColumnType::Boolean) {
            let mut v: Vec<(String, usize)> = freq.iter()
                .map(|(k, v)| (k.clone(), *v))
                .collect();
            v.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
            let most: Vec<(String, usize)> = v.iter().take(5).cloned().collect();
            let mut least_src = v.clone();
            least_src.sort_by(|a, b| a.1.cmp(&b.1).then_with(|| a.0.cmp(&b.0)));
            let least: Vec<(String, usize)> = least_src.iter().take(5).cloned().collect();
            let histogram = if opts.histogram { Some(v) } else { None };
            Some(TopK { most, least, histogram })
        } else {
            None
        };

        // Warnings
        let mut warnings = Vec::new();
        if had_conflict {
            warnings.push("mixed types observed in column".into());
        }
        let is_constant = non_null > 0 && unique.map(|u| u <= 1).unwrap_or(false);
        if is_constant {
            warnings.push("column is constant (<= 1 distinct non-null value)".into());
        }
        if let Some(u) = unique {
            if final_type == ColumnType::Text && u > 1 && u <= opts.categorical_threshold * 2 {
                warnings.push(format!(
                    "column has only {} distinct values; consider treating as categorical",
                    u
                ));
            }
        }

        ColumnReport {
            name:        column_name,
            inferred:    final_type,
            row_count:   seen,
            null_count:  nulls,
            null_pct,
            unique_count: unique,
            numeric_stats,
            date_range,
            min_str_len: min_len,
            max_str_len: max_len,
            top_k,
            warnings,
        }
    }
}

/// Linear-interpolated percentile on a pre-sorted slice.
fn percentile(sorted: &[f64], p: f64) -> f64 {
    if sorted.is_empty() { return f64::NAN; }
    if sorted.len() == 1 { return sorted[0]; }
    let rank = (p / 100.0) * (sorted.len() - 1) as f64;
    let lo = rank.floor() as usize;
    let hi = rank.ceil() as usize;
    if lo == hi { return sorted[lo]; }
    let frac = rank - lo as f64;
    sorted[lo] * (1.0 - frac) + sorted[hi] * frac
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn integer_column_stats() {
        let opts = AnalyzerOptions { percentiles: true, ..Default::default() };
        let mut a = Box::new(StandardAnalyzer::new(opts));
        for v in ["1", "2", "3", "4", "5"] { a.observe(v); }
        let r = a.finalize("x".into());
        assert_eq!(r.inferred, ColumnType::Integer);
        let n = r.numeric_stats.unwrap();
        assert!((n.mean - 3.0).abs() < 1e-9);
        assert!((n.median - 3.0).abs() < 1e-9);
        assert_eq!(n.min, 1.0);
        assert_eq!(n.max, 5.0);
        assert!(n.percentiles.is_some());
    }

    #[test]
    fn mixed_type_warning() {
        let mut a = Box::new(StandardAnalyzer::new(AnalyzerOptions::default()));
        for v in ["1", "2", "hello"] { a.observe(v); }
        let r = a.finalize("x".into());
        assert!(r.warnings.iter().any(|w| w.contains("mixed")));
    }

    #[test]
    fn constant_column_warning() {
        let mut a = Box::new(StandardAnalyzer::new(AnalyzerOptions::default()));
        for _ in 0..10 { a.observe("X"); }
        let r = a.finalize("x".into());
        assert!(r.warnings.iter().any(|w| w.contains("constant")));
    }

    #[test]
    fn nulls_counted() {
        let mut a = Box::new(StandardAnalyzer::new(AnalyzerOptions::default()));
        for v in ["1", "", "NA", "2", "-"] { a.observe(v); }
        let r = a.finalize("x".into());
        assert_eq!(r.row_count, 5);
        assert_eq!(r.null_count, 3);
    }

    #[test]
    fn percentile_math() {
        let s = [1.0, 2.0, 3.0, 4.0, 5.0];
        assert!((percentile(&s, 50.0) - 3.0).abs() < 1e-9);
        assert!((percentile(&s,  0.0) - 1.0).abs() < 1e-9);
        assert!((percentile(&s,100.0) - 5.0).abs() < 1e-9);
    }
}
