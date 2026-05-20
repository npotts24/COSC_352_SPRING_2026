use crate::types::{Accumulator, ColumnProfile};
use ordered_float::OrderedFloat;
use std::collections::HashMap;

// ============================================================================
// Numeric accumulator (Integer & Float)
// ============================================================================

pub struct NumericAccumulator {
    values: Vec<f64>,
    sum: f64,
    sum_sq: f64,
    count: usize,
    min: f64,
    max: f64,
}

impl NumericAccumulator {
    pub fn new() -> Self {
        Self {
            values: Vec::new(),
            sum: 0.0,
            sum_sq: 0.0,
            count: 0,
            min: f64::INFINITY,
            max: f64::NEG_INFINITY,
        }
    }

    /// Compute the value at a given percentile (0..100) from a sorted slice.
    fn percentile(sorted: &[f64], p: f64) -> f64 {
        if sorted.is_empty() {
            return f64::NAN;
        }
        if sorted.len() == 1 {
            return sorted[0];
        }
        let rank = p / 100.0 * (sorted.len() as f64 - 1.0);
        let lo = rank.floor() as usize;
        let hi = rank.ceil() as usize;
        let frac = rank - lo as f64;
        sorted[lo] * (1.0 - frac) + sorted[hi] * frac
    }
}

impl Accumulator for NumericAccumulator {
    fn observe(&mut self, value: &str) {
        if let Ok(v) = value.parse::<f64>() {
            self.values.push(v);
            self.sum += v;
            self.sum_sq += v * v;
            self.count += 1;
            if v < self.min {
                self.min = v;
            }
            if v > self.max {
                self.max = v;
            }
        }
    }

    fn finalize(
        &mut self,
        profile: &mut ColumnProfile,
        percentiles: bool,
        _histogram: bool,
        _top_n: usize,
    ) {
        if self.count == 0 {
            return;
        }

        profile.min_numeric = Some(self.min);
        profile.max_numeric = Some(self.max);

        let mean = self.sum / self.count as f64;
        profile.mean = Some(mean);

        let variance = (self.sum_sq / self.count as f64) - mean * mean;
        profile.std_dev = Some(variance.max(0.0).sqrt());

        // Sort for median & percentiles
        self.values.sort_by_key(|v| OrderedFloat(*v));
        profile.median = Some(Self::percentile(&self.values, 50.0));

        if percentiles {
            profile.p5 = Some(Self::percentile(&self.values, 5.0));
            profile.p25 = Some(Self::percentile(&self.values, 25.0));
            profile.p75 = Some(Self::percentile(&self.values, 75.0));
            profile.p95 = Some(Self::percentile(&self.values, 95.0));
        }

        // Outlier detection via IQR
        let q1 = Self::percentile(&self.values, 25.0);
        let q3 = Self::percentile(&self.values, 75.0);
        let iqr = q3 - q1;
        if iqr > 0.0 {
            let lower = q1 - 1.5 * iqr;
            let upper = q3 + 1.5 * iqr;
            let outlier_count = self
                .values
                .iter()
                .filter(|v| **v < lower || **v > upper)
                .count();
            if outlier_count > 0 {
                profile.warnings.push(format!(
                    "{outlier_count} outlier(s) detected (IQR method, bounds [{lower:.2}, {upper:.2}])"
                ));
            }
        }
    }
}

// ============================================================================
// Boolean accumulator
// ============================================================================

pub struct BooleanAccumulator {
    freq: HashMap<String, usize>,
}

impl BooleanAccumulator {
    pub fn new() -> Self {
        Self {
            freq: HashMap::new(),
        }
    }
}

impl Accumulator for BooleanAccumulator {
    fn observe(&mut self, value: &str) {
        *self.freq.entry(value.to_lowercase()).or_insert(0) += 1;
    }

    fn finalize(
        &mut self,
        profile: &mut ColumnProfile,
        _percentiles: bool,
        histogram: bool,
        top_n: usize,
    ) {
        let sorted = sorted_freq(&self.freq);
        profile.top_values = Some(sorted.iter().take(top_n).cloned().collect());
        profile.bottom_values = Some(sorted.iter().rev().take(top_n).cloned().collect());
        if histogram {
            profile.histogram = Some(sorted);
        }
    }
}

// ============================================================================
// Date accumulator
// ============================================================================

pub struct DateAccumulator {
    min: Option<String>,
    max: Option<String>,
}

impl DateAccumulator {
    pub fn new() -> Self {
        Self {
            min: None,
            max: None,
        }
    }
}

impl Accumulator for DateAccumulator {
    fn observe(&mut self, value: &str) {
        // Store raw strings; comparison is lexicographic which works well for
        // ISO-style dates. For other formats we just keep first/last seen
        // — good enough for a profiling overview.
        match &self.min {
            None => {
                self.min = Some(value.to_owned());
                self.max = Some(value.to_owned());
            }
            Some(current_min) => {
                if value < current_min.as_str() {
                    self.min = Some(value.to_owned());
                }
                if let Some(current_max) = &self.max {
                    if value > current_max.as_str() {
                        self.max = Some(value.to_owned());
                    }
                }
            }
        }
    }

    fn finalize(
        &mut self,
        profile: &mut ColumnProfile,
        _percentiles: bool,
        _histogram: bool,
        _top_n: usize,
    ) {
        profile.min_date = self.min.take();
        profile.max_date = self.max.take();
    }
}

// ============================================================================
// Categorical accumulator
// ============================================================================

pub struct CategoricalAccumulator {
    freq: HashMap<String, usize>,
}

impl CategoricalAccumulator {
    pub fn new() -> Self {
        Self {
            freq: HashMap::new(),
        }
    }
}

impl Accumulator for CategoricalAccumulator {
    fn observe(&mut self, value: &str) {
        *self.freq.entry(value.to_owned()).or_insert(0) += 1;
    }

    fn finalize(
        &mut self,
        profile: &mut ColumnProfile,
        _percentiles: bool,
        histogram: bool,
        top_n: usize,
    ) {
        let sorted = sorted_freq(&self.freq);
        profile.top_values = Some(sorted.iter().take(top_n).cloned().collect());
        profile.bottom_values = Some(sorted.iter().rev().take(top_n).cloned().collect());

        // Low-cardinality warning
        if self.freq.len() <= 2 && self.freq.len() > 0 {
            profile
                .warnings
                .push(format!("Low cardinality: only {} distinct value(s)", self.freq.len()));
        }

        if histogram {
            profile.histogram = Some(sorted);
        }
    }
}

// ============================================================================
// Text accumulator
// ============================================================================

pub struct TextAccumulator {
    shortest: Option<usize>,
    longest: Option<usize>,
}

impl TextAccumulator {
    pub fn new() -> Self {
        Self {
            shortest: None,
            longest: None,
        }
    }
}

impl Accumulator for TextAccumulator {
    fn observe(&mut self, value: &str) {
        let len = value.len();
        self.shortest = Some(self.shortest.map_or(len, |s| s.min(len)));
        self.longest = Some(self.longest.map_or(len, |l| l.max(len)));
    }

    fn finalize(
        &mut self,
        profile: &mut ColumnProfile,
        _percentiles: bool,
        _histogram: bool,
        _top_n: usize,
    ) {
        profile.shortest_length = self.shortest;
        profile.longest_length = self.longest;
    }
}

// ============================================================================
// Helpers
// ============================================================================

/// Sort a frequency map descending by count, then ascending by key.
fn sorted_freq(freq: &HashMap<String, usize>) -> Vec<(String, usize)> {
    let mut pairs: Vec<(String, usize)> = freq
        .iter()
        .map(|(k, v)| (k.clone(), *v))
        .collect();
    pairs.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    pairs
}

// ============================================================================
// Factory function — selects the right accumulator for a given column type
// ============================================================================

use crate::types::ColumnType;

pub fn make_accumulator(col_type: ColumnType) -> Box<dyn Accumulator> {
    match col_type {
        ColumnType::Integer | ColumnType::Float => Box::new(NumericAccumulator::new()),
        ColumnType::Boolean => Box::new(BooleanAccumulator::new()),
        ColumnType::Date => Box::new(DateAccumulator::new()),
        ColumnType::Categorical => Box::new(CategoricalAccumulator::new()),
        ColumnType::Text => Box::new(TextAccumulator::new()),
    }
}