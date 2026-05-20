use std::collections::hash_map::DefaultHasher;
use std::collections::{BinaryHeap, HashMap, HashSet};
use std::hash::{Hash, Hasher};

use chrono::{NaiveDateTime, Timelike};
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

use crate::types::{ColumnReport, FrequencyEntry, InferredType, PercentileValue};

pub trait ColumnStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        inferred_type: InferredType,
        top_k: usize,
        requested_percentiles: &[f64],
    );
}

pub trait NumericAccumulator {
    fn update_numeric(&mut self, value: f64);
}

pub trait FrequencyAccumulator {
    fn update_text(&mut self, value: &str);
}

#[derive(Debug, Clone)]
pub struct LexicalStats {
    non_null_count: u64,
    total_len: u64,
    distinct: DistinctCounter,
    heavy_hitters: HeavyHitters,
}

impl LexicalStats {
    pub fn new(distinct_capacity: usize, heavy_hitter_capacity: usize) -> Self {
        Self {
            non_null_count: 0,
            total_len: 0,
            distinct: DistinctCounter::new(distinct_capacity),
            heavy_hitters: HeavyHitters::new(heavy_hitter_capacity),
        }
    }

    pub fn avg_len(&self) -> f64 {
        if self.non_null_count == 0 {
            0.0
        } else {
            self.total_len as f64 / self.non_null_count as f64
        }
    }

    pub fn distinct_count(&self) -> (u64, bool) {
        self.distinct.estimate()
    }

    pub fn top_values(&self, limit: usize) -> Vec<FrequencyEntry> {
        self.heavy_hitters.top(limit, self.non_null_count)
    }

    pub fn notes(&self) -> Vec<String> {
        let mut notes = Vec::new();
        if self.heavy_hitters.is_approximate() {
            notes.push(format!(
                "top values are approximate heavy hitters (capacity={})",
                self.heavy_hitters.capacity()
            ));
        }
        let (_, approximate_distinct) = self.distinct_count();
        if approximate_distinct {
            notes.push(format!(
                "distinct count is approximate once cardinality exceeds {} values",
                self.distinct.capacity()
            ));
        }
        notes
    }
}

impl FrequencyAccumulator for LexicalStats {
    fn update_text(&mut self, value: &str) {
        self.non_null_count += 1;
        self.total_len += value.len() as u64;
        self.distinct.observe(value);
        self.heavy_hitters.observe(value);
    }
}

#[derive(Debug, Clone)]
pub struct NumericStats {
    count: u64,
    mean: f64,
    m2: f64,
    min: Option<f64>,
    max: Option<f64>,
    reservoir: ReservoirSampler,
}

impl NumericStats {
    pub fn new(sample_size: usize) -> Self {
        Self {
            count: 0,
            mean: 0.0,
            m2: 0.0,
            min: None,
            max: None,
            reservoir: ReservoirSampler::new(sample_size),
        }
    }
}

impl NumericAccumulator for NumericStats {
    fn update_numeric(&mut self, value: f64) {
        self.count += 1;
        let delta = value - self.mean;
        self.mean += delta / self.count as f64;
        let delta2 = value - self.mean;
        self.m2 += delta * delta2;
        self.min = Some(self.min.map_or(value, |current| current.min(value)));
        self.max = Some(self.max.map_or(value, |current| current.max(value)));
        self.reservoir.observe(value);
    }
}

impl ColumnStats for NumericStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        inferred_type: InferredType,
        _top_k: usize,
        requested_percentiles: &[f64],
    ) {
        if self.count == 0 {
            return;
        }

        report.min = self.min.map(|value| format_numeric(value, inferred_type));
        report.max = self.max.map(|value| format_numeric(value, inferred_type));
        report.mean = Some(self.mean);
        report.std_dev = if self.count > 1 {
            Some((self.m2 / (self.count as f64 - 1.0)).sqrt())
        } else {
            Some(0.0)
        };

        let mut requests = requested_percentiles.to_vec();
        if !requests
            .iter()
            .any(|value| (*value - 50.0).abs() < f64::EPSILON)
        {
            requests.push(50.0);
        }

        let values = self.reservoir.percentiles(&requests);
        for percentile in values {
            if (percentile.percentile - 50.0).abs() < f64::EPSILON {
                report.median = Some(percentile.value);
            } else {
                report.percentiles.push(percentile);
            }
        }

        if self.reservoir.is_approximate(self.count) {
            report.notes.push(format!(
                "median and percentiles come from a bounded reservoir sample (size={})",
                self.reservoir.capacity()
            ));
        }
    }
}

#[derive(Debug, Clone)]
pub struct DateStats {
    min: Option<NaiveDateTime>,
    max: Option<NaiveDateTime>,
}

impl DateStats {
    pub fn new() -> Self {
        Self {
            min: None,
            max: None,
        }
    }

    pub fn update(&mut self, value: NaiveDateTime) {
        self.min = Some(self.min.map_or(value, |current| current.min(value)));
        self.max = Some(self.max.map_or(value, |current| current.max(value)));
    }
}

impl ColumnStats for DateStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        _inferred_type: InferredType,
        _top_k: usize,
        _requested_percentiles: &[f64],
    ) {
        report.min = self.min.map(format_datetime);
        report.max = self.max.map(format_datetime);
    }
}

#[derive(Debug, Clone)]
pub struct CategoricalColumnStats {
    lexical: LexicalStats,
}

impl CategoricalColumnStats {
    pub fn new(lexical: LexicalStats) -> Self {
        Self { lexical }
    }
}

#[derive(Debug, Clone)]
pub struct NumericColumnStats {
    numeric: NumericStats,
    lexical: LexicalStats,
}

impl NumericColumnStats {
    pub fn new(numeric: NumericStats, lexical: LexicalStats) -> Self {
        Self { numeric, lexical }
    }
}

impl ColumnStats for NumericColumnStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        inferred_type: InferredType,
        top_k: usize,
        requested_percentiles: &[f64],
    ) {
        self.numeric
            .finalize(report, inferred_type, top_k, requested_percentiles);
        let (distinct, approximate) = self.lexical.distinct_count();
        report.distinct_count = Some(distinct);
        report.distinct_is_approximate = approximate;
        report.top_values = self.lexical.top_values(top_k);
        report.notes.extend(self.lexical.notes());
    }
}

#[derive(Debug, Clone)]
pub struct DateColumnStats {
    dates: DateStats,
    lexical: LexicalStats,
}

impl DateColumnStats {
    pub fn new(dates: DateStats, lexical: LexicalStats) -> Self {
        Self { dates, lexical }
    }
}

impl ColumnStats for DateColumnStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        inferred_type: InferredType,
        top_k: usize,
        requested_percentiles: &[f64],
    ) {
        self.dates
            .finalize(report, inferred_type, top_k, requested_percentiles);
        let (distinct, approximate) = self.lexical.distinct_count();
        report.distinct_count = Some(distinct);
        report.distinct_is_approximate = approximate;
        report.top_values = self.lexical.top_values(top_k);
        report.notes.extend(self.lexical.notes());
    }
}

impl ColumnStats for CategoricalColumnStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        _inferred_type: InferredType,
        top_k: usize,
        _requested_percentiles: &[f64],
    ) {
        let (distinct, approximate) = self.lexical.distinct_count();
        report.distinct_count = Some(distinct);
        report.distinct_is_approximate = approximate;
        report.top_values = self.lexical.top_values(top_k);
        report.notes.extend(self.lexical.notes());
    }
}

#[derive(Debug, Clone)]
pub struct TextColumnStats {
    lexical: LexicalStats,
}

impl TextColumnStats {
    pub fn new(lexical: LexicalStats) -> Self {
        Self { lexical }
    }
}

impl ColumnStats for TextColumnStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        _inferred_type: InferredType,
        top_k: usize,
        _requested_percentiles: &[f64],
    ) {
        let (distinct, approximate) = self.lexical.distinct_count();
        report.distinct_count = Some(distinct);
        report.distinct_is_approximate = approximate;
        report.top_values = self.lexical.top_values(top_k);
        report.notes.extend(self.lexical.notes());
        report.notes.push(format!(
            "average trimmed length {:.1} characters",
            self.lexical.avg_len()
        ));
    }
}

#[derive(Debug, Clone)]
pub struct BoolColumnStats {
    lexical: LexicalStats,
    true_count: u64,
    false_count: u64,
}

impl BoolColumnStats {
    pub fn new(lexical: LexicalStats, true_count: u64, false_count: u64) -> Self {
        Self {
            lexical,
            true_count,
            false_count,
        }
    }
}

impl ColumnStats for BoolColumnStats {
    fn finalize(
        &self,
        report: &mut ColumnReport,
        _inferred_type: InferredType,
        top_k: usize,
        _requested_percentiles: &[f64],
    ) {
        let (distinct, approximate) = self.lexical.distinct_count();
        report.distinct_count = Some(distinct);
        report.distinct_is_approximate = approximate;
        report.top_values = self.lexical.top_values(top_k);
        report.notes.extend(self.lexical.notes());
        report.notes.push(format!(
            "true={} false={}",
            self.true_count, self.false_count
        ));
    }
}

#[derive(Debug, Clone)]
pub struct ReservoirSampler {
    capacity: usize,
    values: Vec<f64>,
    seen: u64,
    rng: StdRng,
}

impl ReservoirSampler {
    fn new(capacity: usize) -> Self {
        Self {
            capacity,
            values: Vec::with_capacity(capacity),
            seen: 0,
            rng: StdRng::from_entropy(),
        }
    }

    fn observe(&mut self, value: f64) {
        self.seen += 1;
        if self.values.len() < self.capacity {
            self.values.push(value);
            return;
        }

        let slot = self.rng.gen_range(0..self.seen);
        if (slot as usize) < self.capacity {
            self.values[slot as usize] = value;
        }
    }

    fn percentiles(&self, requested: &[f64]) -> Vec<PercentileValue> {
        if self.values.is_empty() {
            return Vec::new();
        }

        let mut data = self.values.clone();
        data.sort_by(|left, right| left.total_cmp(right));

        let mut percentiles = requested.to_vec();
        percentiles.sort_by(|left, right| left.total_cmp(right));
        percentiles.dedup_by(|left, right| (*left - *right).abs() < f64::EPSILON);

        percentiles
            .into_iter()
            .map(|percentile| PercentileValue {
                percentile,
                value: percentile_from_sorted(&data, percentile),
            })
            .collect()
    }

    fn capacity(&self) -> usize {
        self.capacity
    }

    fn is_approximate(&self, total_count: u64) -> bool {
        total_count as usize > self.capacity
    }
}

#[derive(Debug, Clone)]
pub struct DistinctCounter {
    capacity: usize,
    state: DistinctState,
}

#[derive(Debug, Clone)]
enum DistinctState {
    Exact(HashSet<u64>),
    Sketch(KmvSketch),
}

impl DistinctCounter {
    fn new(capacity: usize) -> Self {
        Self {
            capacity,
            state: DistinctState::Exact(HashSet::with_capacity(capacity)),
        }
    }

    fn observe<T: Hash>(&mut self, value: T) {
        let hash = hash_value(value);
        match &mut self.state {
            DistinctState::Exact(values) => {
                values.insert(hash);
                if values.len() > self.capacity {
                    let mut sketch = KmvSketch::new(self.capacity);
                    for &item in values.iter() {
                        sketch.observe_hash(item);
                    }
                    self.state = DistinctState::Sketch(sketch);
                }
            }
            DistinctState::Sketch(sketch) => sketch.observe_hash(hash),
        }
    }

    fn estimate(&self) -> (u64, bool) {
        match &self.state {
            DistinctState::Exact(values) => (values.len() as u64, false),
            DistinctState::Sketch(sketch) => (sketch.estimate(), true),
        }
    }

    fn capacity(&self) -> usize {
        self.capacity
    }
}

#[derive(Debug, Clone)]
struct KmvSketch {
    capacity: usize,
    heap: BinaryHeap<u64>,
    tracked: HashSet<u64>,
}

impl KmvSketch {
    fn new(capacity: usize) -> Self {
        Self {
            capacity,
            heap: BinaryHeap::with_capacity(capacity),
            tracked: HashSet::with_capacity(capacity),
        }
    }

    fn observe_hash(&mut self, hash: u64) {
        if self.tracked.contains(&hash) {
            return;
        }

        if self.heap.len() < self.capacity {
            self.heap.push(hash);
            self.tracked.insert(hash);
            return;
        }

        let largest = self.heap.peek().copied().unwrap_or(hash);
        if hash >= largest {
            return;
        }

        if let Some(removed) = self.heap.pop() {
            self.tracked.remove(&removed);
        }
        self.heap.push(hash);
        self.tracked.insert(hash);
    }

    fn estimate(&self) -> u64 {
        if self.heap.is_empty() {
            return 0;
        }
        if self.heap.len() < self.capacity {
            return self.heap.len() as u64;
        }

        let kth = *self.heap.peek().expect("heap is not empty") as f64 / u64::MAX as f64;
        if kth <= 0.0 {
            self.capacity as u64
        } else {
            (((self.capacity - 1) as f64) / kth).round() as u64
        }
    }
}

#[derive(Debug, Clone)]
pub struct HeavyHitters {
    capacity: usize,
    approximate: bool,
    counts: HashMap<String, CounterEntry>,
}

#[derive(Debug, Clone, Copy)]
struct CounterEntry {
    count: u64,
    error: u64,
}

impl HeavyHitters {
    fn new(capacity: usize) -> Self {
        Self {
            capacity,
            approximate: false,
            counts: HashMap::with_capacity(capacity),
        }
    }

    fn observe(&mut self, value: &str) {
        if let Some(entry) = self.counts.get_mut(value) {
            entry.count += 1;
            return;
        }

        if self.counts.len() < self.capacity {
            self.counts
                .insert(value.to_string(), CounterEntry { count: 1, error: 0 });
            return;
        }

        let Some((victim_key, victim_entry)) = self
            .counts
            .iter()
            .min_by_key(|(_, entry)| entry.count)
            .map(|(key, entry)| (key.clone(), *entry))
        else {
            return;
        };

        self.counts.remove(&victim_key);
        self.counts.insert(
            value.to_string(),
            CounterEntry {
                count: victim_entry.count + 1,
                error: victim_entry.count,
            },
        );
        self.approximate = true;
    }

    fn top(&self, limit: usize, total_count: u64) -> Vec<FrequencyEntry> {
        let mut entries: Vec<_> = self.counts.iter().collect();
        entries.sort_by(|left, right| {
            right
                .1
                .count
                .cmp(&left.1.count)
                .then_with(|| left.0.cmp(right.0))
        });

        entries
            .into_iter()
            .take(limit)
            .map(|(value, entry)| FrequencyEntry {
                value: value.clone(),
                count: entry.count.saturating_sub(entry.error),
                ratio: if total_count == 0 {
                    0.0
                } else {
                    entry.count.saturating_sub(entry.error) as f64 / total_count as f64
                },
            })
            .collect()
    }

    fn capacity(&self) -> usize {
        self.capacity
    }

    fn is_approximate(&self) -> bool {
        self.approximate
    }
}

fn hash_value<T: Hash>(value: T) -> u64 {
    let mut hasher = DefaultHasher::new();
    value.hash(&mut hasher);
    hasher.finish()
}

fn percentile_from_sorted(sorted: &[f64], percentile: f64) -> f64 {
    if sorted.len() == 1 {
        return sorted[0];
    }

    let position = percentile.clamp(0.0, 100.0) / 100.0 * (sorted.len() - 1) as f64;
    let lower = position.floor() as usize;
    let upper = position.ceil() as usize;
    if lower == upper {
        return sorted[lower];
    }

    let weight = position - lower as f64;
    sorted[lower] * (1.0 - weight) + sorted[upper] * weight
}

fn format_datetime(value: NaiveDateTime) -> String {
    if value.time().num_seconds_from_midnight() == 0 {
        value.format("%Y-%m-%d").to_string()
    } else {
        value.format("%Y-%m-%d %H:%M:%S").to_string()
    }
}

pub fn format_numeric(value: f64, inferred_type: InferredType) -> String {
    match inferred_type {
        InferredType::Int => format!("{}", value.round() as i64),
        _ => {
            if value.fract().abs() < 1e-9 {
                format!("{value:.1}")
            } else {
                format!("{value:.6}")
            }
        }
    }
}
