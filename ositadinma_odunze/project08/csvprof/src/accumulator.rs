//! Per-column streaming accumulator.
//!
//! The `ColumnAccumulator` ingests one cell at a time without keeping
//! the raw strings in memory.  After all rows have been fed, `finalize`
//! converts the accumulated state into a `ColumnProfile`.

use std::collections::HashMap;

use crate::{
    infer,
    types::{
        CategoricalStats, ColumnProfile, InferredType, NumericStats, TextStats,
    },
};

/// Configuration that controls accumulator behaviour.
pub struct AccumulatorConfig {
    /// Columns with unique-value count ≤ this are treated as Categorical.
    pub categorical_threshold: usize,
    /// Maximum distinct values stored in the frequency map.
    pub max_categories: usize,
    /// Whether to compute extended percentiles (p5/p25/p75/p95).
    pub compute_percentiles: bool,
    /// Whether to emit the full frequency histogram.
    pub emit_histogram: bool,
}

/// A trait that every column-level accumulator implements.
/// Using a trait lets callers hold a `Vec<Box<dyn Profiler>>` and
/// swap in alternative implementations (e.g., approximate sketches for
/// very high-cardinality columns) without changing the orchestration logic.
pub trait Profiler: Send {
    fn feed(&mut self, value: Option<&str>);
    fn finalize(self: Box<Self>, cfg: &AccumulatorConfig) -> ColumnProfile;
    fn name(&self) -> &str;
}

/// Streaming accumulator for a single CSV column.
pub struct ColumnAccumulator {
    pub col_name: String,

    // ── bookkeeping ──────────────────────────────────────────────────────────
    row_count:  u64,
    null_count: u64,

    // ── type-compatibility flags ─────────────────────────────────────────────
    // These start as `true` and flip to `false` on the first value that
    // fails the corresponding parse.  After streaming, the highest-priority
    // type whose flag is still `true` wins.
    can_be_int:   bool,
    can_be_float: bool,
    can_be_bool:  bool,
    can_be_date:  bool,

    // per-type non-null hit counts (for mixed-type detection)
    int_hits:   u64,
    float_hits: u64,
    bool_hits:  u64,
    date_hits:  u64,

    // ── numeric accumulation ─────────────────────────────────────────────────
    /// Only non-null numeric values; kept for median/percentile computation.
    numeric_values: Vec<f64>,
    numeric_sum:    f64,
    numeric_min:    f64,
    numeric_max:    f64,

    // ── string / text accumulation ───────────────────────────────────────────
    total_chars: u64,
    min_len:     usize,
    max_len:     usize,

    // ── cardinality / frequency ──────────────────────────────────────────────
    freq_map:    HashMap<String, u64>,
    freq_capped: bool,
    max_cap:     usize,

    // ── constant-column detection ─────────────────────────────────────────────
    first_non_null: Option<String>,
    is_constant:    bool,
}

impl ColumnAccumulator {
    pub fn new(name: &str, max_categories: usize) -> Self {
        Self {
            col_name:       name.to_owned(),
            row_count:      0,
            null_count:     0,
            can_be_int:     true,
            can_be_float:   true,
            can_be_bool:    true,
            can_be_date:    true,
            int_hits:       0,
            float_hits:     0,
            bool_hits:      0,
            date_hits:      0,
            numeric_values: Vec::new(),
            numeric_sum:    0.0,
            numeric_min:    f64::MAX,
            numeric_max:    f64::MIN,
            total_chars:    0,
            min_len:        usize::MAX,
            max_len:        0,
            freq_map:       HashMap::new(),
            freq_capped:    false,
            max_cap:        max_categories,
            first_non_null: None,
            is_constant:    true,
        }
    }

    /// Feed one cell value (None = null / empty).
    pub fn feed(&mut self, value: Option<&str>) {
        self.row_count += 1;

        let raw = match value {
            None => { self.null_count += 1; return; }
            Some(s) if s.trim().is_empty() => { self.null_count += 1; return; }
            Some(s) => s,
        };

        // ── constant-column tracking ─────────────────────────────────────
        match &self.first_non_null {
            None => { self.first_non_null = Some(raw.to_owned()); }
            Some(first) if first != raw => { self.is_constant = false; }
            _ => {}
        }

        // ── type inference ───────────────────────────────────────────────
        let is_int   = infer::try_int(raw);
        let is_float = infer::try_float(raw);
        let is_bool  = infer::try_bool(raw);
        let is_date  = infer::try_date(raw);

        if is_int   { self.int_hits   += 1; } else { self.can_be_int   = false; }
        if is_float { self.float_hits += 1; } else { self.can_be_float = false; }
        if is_bool  { self.bool_hits  += 1; } else { self.can_be_bool  = false; }
        if is_date  { self.date_hits  += 1; } else { self.can_be_date  = false; }

        // ── numeric accumulation ─────────────────────────────────────────
        if let Some(v) = infer::parse_f64(raw) {
            self.numeric_values.push(v);
            self.numeric_sum += v;
            if v < self.numeric_min { self.numeric_min = v; }
            if v > self.numeric_max { self.numeric_max = v; }
        }

        // ── string stats ─────────────────────────────────────────────────
        let len = raw.chars().count();
        self.total_chars += len as u64;
        if len < self.min_len { self.min_len = len; }
        if len > self.max_len { self.max_len = len; }

        // ── frequency map ────────────────────────────────────────────────
        if !self.freq_capped {
            let entry = self.freq_map.entry(raw.to_owned()).or_insert(0);
            *entry += 1;
            if self.freq_map.len() > self.max_cap {
                self.freq_capped = true;
            }
        } else {
            if let Some(cnt) = self.freq_map.get_mut(raw) {
                *cnt += 1;
            }
        }
    }

    /// Convert accumulated state into a finished `ColumnProfile`.
    pub fn finalize(mut self, cfg: &AccumulatorConfig) -> ColumnProfile {
        let non_null = self.row_count - self.null_count;
        let null_pct = if self.row_count == 0 {
            0.0
        } else {
            self.null_count as f64 / self.row_count as f64 * 100.0
        };

        let unique_count = self.freq_map.len() as u64;

        // ── determine inferred type ──────────────────────────────────────
        // Priority: boolean > integer > float > date > categorical > text.
        let inferred_type = if non_null == 0 {
            InferredType::Text
        } else if self.can_be_bool && self.bool_hits == non_null {
            InferredType::Boolean
        } else if self.can_be_int && self.int_hits == non_null {
            InferredType::Integer
        } else if self.can_be_float && self.float_hits == non_null {
            InferredType::Float
        } else if self.can_be_date && self.date_hits == non_null {
            InferredType::Date
        } else if !self.freq_capped && unique_count <= cfg.categorical_threshold as u64 {
            InferredType::Categorical
        } else {
            InferredType::Text
        };

        // ── warnings ─────────────────────────────────────────────────────
        let mut warnings: Vec<String> = Vec::new();

        // Constant column
        if self.is_constant && non_null > 0 {
            warnings.push("Constant column — all non-null values are identical.".into());
        }

        // Low-cardinality categorical
        if matches!(inferred_type, InferredType::Categorical) && unique_count == 1 {
            warnings.push("Low-cardinality categorical — only 1 unique value.".into());
        }

        // Mixed-type: text column where multiple type families have hits
        if matches!(inferred_type, InferredType::Text | InferredType::Categorical) && non_null > 0 {
            let families: Vec<(&str, u64)> = [
                ("integer", self.int_hits),
                ("float",   self.float_hits),
                ("boolean", self.bool_hits),
                ("date",    self.date_hits),
            ]
            .iter()
            .filter(|(_, hits)| *hits > 0)
            .cloned()
            .collect();

            if families.len() >= 2 {
                let detail: Vec<String> = families
                    .iter()
                    .map(|(t, c)| format!("{}: {}", t, c))
                    .collect();
                warnings.push(format!(
                    "Mixed types detected — {}.",
                    detail.join(", ")
                ));
            }

            // Majority-date column that failed due to a few bad values
            if self.date_hits > 0 && !self.can_be_date {
                let bad_count = non_null - self.date_hits;
                let pct = self.date_hits as f64 / non_null as f64 * 100.0;
                if pct >= 70.0 {
                    warnings.push(format!(
                        "Mostly date-like ({:.0}% parsed as date) but {} value(s) \
                         could not be parsed — check for format inconsistencies.",
                        pct, bad_count
                    ));
                }
            }
        }

        // Frequency map capped
        if self.freq_capped {
            warnings.push(format!(
                "Frequency map capped at {} entries; unique count is a lower bound.",
                cfg.max_categories
            ));
        }

        // High null rate
        if null_pct >= 50.0 {
            warnings.push(format!(
                "High null rate ({:.1}%) — column may not be reliable.",
                null_pct
            ));
        }

        // ── numeric stats ────────────────────────────────────────────────
        let numeric_stats = if matches!(
            inferred_type,
            InferredType::Integer | InferredType::Float
        ) && !self.numeric_values.is_empty() {
            let n = self.numeric_values.len() as f64;
            let mean = self.numeric_sum / n;

            self.numeric_values.sort_by(|a, b| a.partial_cmp(b).unwrap());
            let median = percentile_sorted(&self.numeric_values, 50.0);

            let variance = self
                .numeric_values
                .iter()
                .map(|v| (v - mean).powi(2))
                .sum::<f64>()
                / n;
            let std_dev = variance.sqrt();

            let (p5, p25, p75, p95) = if cfg.compute_percentiles {
                (
                    Some(percentile_sorted(&self.numeric_values, 5.0)),
                    Some(percentile_sorted(&self.numeric_values, 25.0)),
                    Some(percentile_sorted(&self.numeric_values, 75.0)),
                    Some(percentile_sorted(&self.numeric_values, 95.0)),
                )
            } else {
                (None, None, None, None)
            };

            Some(NumericStats {
                min: self.numeric_min,
                max: self.numeric_max,
                mean,
                median,
                std_dev,
                p5, p25, p75, p95,
            })
        } else {
            None
        };

        // ── text stats ───────────────────────────────────────────────────
        let text_stats = if matches!(inferred_type, InferredType::Text) && non_null > 0 {
            Some(TextStats {
                min_length: if self.min_len == usize::MAX { 0 } else { self.min_len },
                max_length: self.max_len,
                avg_length: self.total_chars as f64 / non_null as f64,
            })
        } else {
            None
        };

        // ── categorical stats ────────────────────────────────────────────
        let categorical_stats = if matches!(
            inferred_type,
            InferredType::Categorical | InferredType::Boolean
        ) && !self.freq_map.is_empty() {
            let mut sorted: Vec<(String, u64)> = self.freq_map.drain().collect();
            sorted.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));

            let top5 = sorted.iter().take(5).cloned().collect();
            let bot5: Vec<(String, u64)> = sorted.iter().rev().take(5).cloned().collect();

            let histogram = if cfg.emit_histogram {
                Some(sorted.clone())
            } else {
                None
            };

            Some(CategoricalStats {
                top_5_most_frequent:  top5,
                top_5_least_frequent: bot5,
                histogram,
            })
        } else {
            None
        };

        ColumnProfile {
            name: self.col_name,
            inferred_type,
            row_count:  self.row_count,
            null_count: self.null_count,
            null_pct,
            unique_count,
            warnings,
            numeric_stats,
            text_stats,
            categorical_stats,
        }
    }
}

impl Profiler for ColumnAccumulator {
    fn feed(&mut self, value: Option<&str>) { self.feed(value) }
    fn finalize(self: Box<Self>, cfg: &AccumulatorConfig) -> ColumnProfile {
        (*self).finalize(cfg)
    }
    fn name(&self) -> &str { &self.col_name }
}

// ── helpers ───────────────────────────────────────────────────────────────────

/// Linear-interpolation percentile on a pre-sorted slice.
/// Uses the same method as NumPy's `percentile(..., interpolation='linear')`.
fn percentile_sorted(sorted: &[f64], pct: f64) -> f64 {
    if sorted.is_empty() { return 0.0; }
    if sorted.len() == 1 { return sorted[0]; }
    let idx  = pct / 100.0 * (sorted.len() - 1) as f64;
    let lo   = idx.floor() as usize;
    let hi   = idx.ceil()  as usize;
    let frac = idx - lo as f64;
    sorted[lo] * (1.0 - frac) + sorted[hi] * frac
}
