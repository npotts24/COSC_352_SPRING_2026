use std::collections::HashMap;
use serde::{Deserialize, Serialize};

/// Welford's online algorithm for mean and variance — O(1) memory.
#[derive(Debug, Default, Clone)]
pub struct OnlineStats {
    pub count: u64,
    mean: f64,
    m2: f64,
    pub min: f64,
    pub max: f64,
    // Reservoir for approximate percentiles (fixed-size sample)
    reservoir: Vec<f64>,
    reservoir_cap: usize,
    rng_state: u64, // simple xorshift for reservoir sampling
}

impl OnlineStats {
    pub fn new(reservoir_cap: usize) -> Self {
        Self {
            min: f64::INFINITY,
            max: f64::NEG_INFINITY,
            reservoir_cap,
            rng_state: 0xdeadbeef_cafebabe,
            ..Default::default()
        }
    }

    fn xorshift(&mut self) -> u64 {
        let mut x = self.rng_state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.rng_state = x;
        x
    }

    pub fn update(&mut self, value: f64) {
        self.count += 1;

        // Welford update
        let delta = value - self.mean;
        self.mean += delta / self.count as f64;
        let delta2 = value - self.mean;
        self.m2 += delta * delta2;

        if value < self.min {
            self.min = value;
        }
        if value > self.max {
            self.max = value;
        }

        // Reservoir sampling
        if self.reservoir.len() < self.reservoir_cap {
            self.reservoir.push(value);
        } else {
            let j = (self.xorshift() % self.count) as usize;
            if j < self.reservoir_cap {
                self.reservoir[j] = value;
            }
        }
    }

    pub fn mean(&self) -> Option<f64> {
        if self.count == 0 { None } else { Some(self.mean) }
    }

    pub fn variance(&self) -> Option<f64> {
        if self.count < 2 {
            None
        } else {
            Some(self.m2 / (self.count - 1) as f64)
        }
    }

    pub fn std_dev(&self) -> Option<f64> {
        self.variance().map(f64::sqrt)
    }

    /// Approximate percentile from reservoir sample (sorted on demand).
    pub fn percentile(&mut self, p: f64) -> Option<f64> {
        if self.reservoir.is_empty() {
            return None;
        }
        self.reservoir.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let idx = ((p / 100.0) * (self.reservoir.len() - 1) as f64).round() as usize;
        Some(self.reservoir[idx.min(self.reservoir.len() - 1)])
    }

    pub fn median(&mut self) -> Option<f64> {
        self.percentile(50.0)
    }
}

/// Tracks frequency counts for categorical / boolean columns.
#[derive(Debug, Default, Clone)]
pub struct FrequencyCounter {
    counts: HashMap<String, u64>,
    pub total: u64,
}

impl FrequencyCounter {
    pub fn observe(&mut self, value: &str) {
        *self.counts.entry(value.to_string()).or_insert(0) += 1;
        self.total += 1;
    }

    pub fn unique_count(&self) -> usize {
        self.counts.len()
    }

    /// Top-N most frequent values.
    pub fn top_n(&self, n: usize) -> Vec<(String, u64)> {
        let mut pairs: Vec<_> = self.counts.iter().map(|(k, v)| (k.clone(), *v)).collect();
        pairs.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
        pairs.truncate(n);
        pairs
    }

    /// Top-N least frequent values.
    pub fn bottom_n(&self, n: usize) -> Vec<(String, u64)> {
        let mut pairs: Vec<_> = self.counts.iter().map(|(k, v)| (k.clone(), *v)).collect();
        pairs.sort_by(|a, b| a.1.cmp(&b.1).then(a.0.cmp(&b.0)));
        pairs.truncate(n);
        pairs
    }

    /// Full histogram sorted by frequency descending.
    pub fn histogram(&self) -> Vec<(String, u64)> {
        let mut pairs: Vec<_> = self.counts.iter().map(|(k, v)| (k.clone(), *v)).collect();
        pairs.sort_by(|a, b| b.1.cmp(&a.1));
        pairs
    }
}

/// Per-column accumulator used during streaming pass.
#[derive(Debug, Clone)]
pub struct ColumnAccumulator {
    pub name: String,
    pub row_count: u64,
    pub null_count: u64,
    pub stats: OnlineStats,
    pub freq: FrequencyCounter,
    /// Tracks unique values (capped to avoid unbounded memory).
    pub unique_tracker: UniqueTracker,
    /// String lengths for text columns.
    pub str_min_len: usize,
    pub str_max_len: usize,
    /// Counts of different parse-type successes for mixed-type detection.
    pub type_vote_numeric: u64,
    pub type_vote_non_numeric: u64,
}

impl ColumnAccumulator {
    pub fn new(name: impl Into<String>, reservoir_cap: usize) -> Self {
        Self {
            name: name.into(),
            row_count: 0,
            null_count: 0,
            stats: OnlineStats::new(reservoir_cap),
            freq: FrequencyCounter::default(),
            unique_tracker: UniqueTracker::new(100_000),
            str_min_len: usize::MAX,
            str_max_len: 0,
            type_vote_numeric: 0,
            type_vote_non_numeric: 0,
        }
    }

    pub fn observe(&mut self, raw: &str) {
        self.row_count += 1;

        if raw.trim().is_empty() {
            self.null_count += 1;
            return;
        }

        let trimmed = raw.trim();

        // String length tracking
        let len = trimmed.len();
        if len < self.str_min_len {
            self.str_min_len = len;
        }
        if len > self.str_max_len {
            self.str_max_len = len;
        }

        // Unique tracker
        self.unique_tracker.insert(trimmed);

        // Frequency (bounded by unique tracker capacity)
        self.freq.observe(trimmed);

        // Numeric stats
        if let Ok(v) = trimmed.parse::<f64>() {
            self.stats.update(v);
            self.type_vote_numeric += 1;
        } else {
            self.type_vote_non_numeric += 1;
        }
    }

    pub fn null_pct(&self) -> f64 {
        if self.row_count == 0 {
            0.0
        } else {
            self.null_count as f64 / self.row_count as f64 * 100.0
        }
    }

    pub fn is_constant(&self) -> bool {
        self.unique_tracker.count() <= 1
    }

    pub fn has_mixed_types(&self) -> bool {
        let non_null = self.row_count - self.null_count;
        if non_null < 10 {
            return false;
        }
        let numeric_ratio = self.type_vote_numeric as f64 / non_null as f64;
        // Mixed if some (but not all) values are numeric (10–90 % range)
        numeric_ratio > 0.05 && numeric_ratio < 0.90
    }
}

/// Approximate unique-value tracker with a hard cap on memory.
#[derive(Debug, Clone)]
pub struct UniqueTracker {
    set: std::collections::HashSet<String>,
    cap: usize,
    overflowed: bool,
}

impl UniqueTracker {
    pub fn new(cap: usize) -> Self {
        Self {
            set: std::collections::HashSet::new(),
            cap,
            overflowed: false,
        }
    }

    pub fn insert(&mut self, value: &str) {
        if self.overflowed {
            return;
        }
        if self.set.len() < self.cap {
            self.set.insert(value.to_string());
        } else if !self.set.contains(value) {
            self.overflowed = true;
        }
    }

    pub fn count(&self) -> usize {
        self.set.len()
    }

    pub fn is_overflowed(&self) -> bool {
        self.overflowed
    }
}

/// Final serialisable statistics per column.
#[derive(Debug, Serialize, Deserialize)]
pub struct ColumnReport {
    pub name: String,
    pub inferred_type: String,
    pub row_count: u64,
    pub null_count: u64,
    pub null_pct: f64,
    pub unique_count: Option<usize>,
    pub unique_count_exact: bool,
    pub min: Option<String>,
    pub max: Option<String>,
    pub mean: Option<f64>,
    pub median: Option<f64>,
    pub std_dev: Option<f64>,
    pub p5: Option<f64>,
    pub p25: Option<f64>,
    pub p75: Option<f64>,
    pub p95: Option<f64>,
    pub top5_most_frequent: Option<Vec<FreqEntry>>,
    pub top5_least_frequent: Option<Vec<FreqEntry>>,
    pub histogram: Option<Vec<FreqEntry>>,
    pub str_min_len: Option<usize>,
    pub str_max_len: Option<usize>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FreqEntry {
    pub value: String,
    pub count: u64,
    pub pct: f64,
}