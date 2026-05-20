use std::io::Read;

use crate::error::{ProfileError, Result};
use crate::stats::{ColumnAccumulator, ColumnReport, FreqEntry};
use crate::types::{ColumnType, TypeVotes};

/// Options controlling profiling behaviour.
#[derive(Debug, Clone)]
pub struct ProfileOptions {
    /// Show percentiles (p5/p25/p75/p95).
    pub percentiles: bool,
    /// Show value-frequency histogram for categorical columns.
    pub histogram: bool,
    /// Cardinality ratio below which a text column becomes Categorical.
    pub categorical_threshold: f64,
    /// Reservoir size for percentile approximation.
    pub reservoir_size: usize,
    /// Maximum distinct values shown in histogram.
    pub max_histogram_bins: usize,
}

impl Default for ProfileOptions {
    fn default() -> Self {
        Self {
            percentiles: false,
            histogram: false,
            categorical_threshold: 0.10,
            reservoir_size: 10_000,
            max_histogram_bins: 20,
        }
    }
}

/// Trait defining the profiling contract. Any source (file, stdin, …) can
/// implement this to feed rows into the profiler.
pub trait DataSource {
    /// Stream all records through `visitor`.
    fn stream<F>(&mut self, headers: &[String], visitor: &mut F) -> Result<()>
    where
        F: FnMut(&[&str]);
}

/// CSV-backed data source.
pub struct CsvSource<R: Read> {
    reader: csv::Reader<R>,
}

impl<R: Read> CsvSource<R> {
    pub fn new(reader: csv::Reader<R>) -> Self {
        Self { reader }
    }
}

impl<R: Read> DataSource for CsvSource<R> {
    fn stream<F>(&mut self, _headers: &[String], visitor: &mut F) -> Result<()>
    where
        F: FnMut(&[&str]),
    {
        let mut record = csv::StringRecord::new();
        while self.reader.read_record(&mut record)? {
            let fields: Vec<&str> = record.iter().collect();
            visitor(&fields);
        }
        Ok(())
    }
}

/// Core profiler — consumes a DataSource and emits ColumnReports.
pub struct Profiler {
    options: ProfileOptions,
}

impl Profiler {
    pub fn new(options: ProfileOptions) -> Self {
        Self { options }
    }

    /// Run the profiling pass and return one report per column.
    pub fn profile<S: DataSource>(
        &self,
        headers: Vec<String>,
        source: &mut S,
    ) -> Result<Vec<ColumnReport>> {
        if headers.is_empty() {
            return Err(ProfileError::EmptyFile);
        }

        // Initialise per-column accumulators.
        let mut accumulators: Vec<ColumnAccumulator> = headers
            .iter()
            .map(|h| ColumnAccumulator::new(h, self.options.reservoir_size))
            .collect();

        // Single streaming pass.
        source.stream(&headers, &mut |fields: &[&str]| {
            for (i, acc) in accumulators.iter_mut().enumerate() {
                let val = fields.get(i).copied().unwrap_or("");
                acc.observe(val);
            }
        })?;

        // Build reports.
        let reports = accumulators
            .into_iter()
            .map(|acc| self.build_report(acc))
            .collect();

        Ok(reports)
    }

    fn build_report(&self, mut acc: ColumnAccumulator) -> ColumnReport {
        let non_null = acc.row_count - acc.null_count;
        let unique_count = acc.unique_tracker.count();

        // Infer type using vote tallies.
        let mut votes = TypeVotes::default();
        // Re-derive votes from numeric split we already tracked.
        votes.non_null = non_null as usize;
        // We approximate: if all numeric votes passed f64, use that ratio.
        let numeric_count = acc.type_vote_numeric as usize;
        votes.float = numeric_count;
        // Re-run integer check: if mean is integer-valued is a heuristic,
        // so we store integer votes via a separate approximation.
        // Use the integer sub-count embedded in the stats count.
        votes.integer = acc.stats.count as usize;

        // For boolean / date: re-derive from freq keys (cheap).
        let non_null_usize = non_null as usize;
        for (val, _) in acc.freq.histogram().iter().take(500) {
            if crate::types::looks_like_boolean(val) {
                votes.boolean += 1;
            }
            if crate::types::looks_like_date(val) {
                votes.date += 1;
            }
        }

        let col_type = votes.resolve(
            unique_count,
            non_null_usize,
            self.options.categorical_threshold,
        );

        // Numeric fields.
        let (mean, median, std_dev, min_s, max_s) = if matches!(
            col_type,
            ColumnType::Integer | ColumnType::Float
        ) {
            let mean = acc.stats.mean();
            let median = acc.stats.median();
            let std_dev = acc.stats.std_dev();
            let min_s = if acc.stats.min.is_finite() {
                Some(format_numeric(acc.stats.min))
            } else {
                None
            };
            let max_s = if acc.stats.max.is_finite() {
                Some(format_numeric(acc.stats.max))
            } else {
                None
            };
            (mean, median, std_dev, min_s, max_s)
        } else if col_type == ColumnType::Date {
            // min/max as strings from frequency map.
            let mut sorted_vals: Vec<_> = acc.freq.histogram();
            sorted_vals.sort_by(|a, b| a.0.cmp(&b.0));
            let min_s = sorted_vals.first().map(|(v, _)| v.clone());
            let max_s = sorted_vals.last().map(|(v, _)| v.clone());
            (None, None, None, min_s, max_s)
        } else {
            (None, None, None, None, None)
        };

        // Percentiles.
        let (p5, p25, p75, p95) = if self.options.percentiles
            && matches!(col_type, ColumnType::Integer | ColumnType::Float)
        {
            (
                acc.stats.percentile(5.0),
                acc.stats.percentile(25.0),
                acc.stats.percentile(75.0),
                acc.stats.percentile(95.0),
            )
        } else {
            (None, None, None, None)
        };

        // Frequency data (categorical, boolean).
        let show_freq = matches!(col_type, ColumnType::Categorical | ColumnType::Boolean);
        let total_freq = acc.freq.total;

        let freq_entry = |v: &str, c: u64| FreqEntry {
            value: v.to_string(),
            count: c,
            pct: if total_freq > 0 {
                c as f64 / total_freq as f64 * 100.0
            } else {
                0.0
            },
        };

        let top5_most_frequent = if show_freq {
            Some(
                acc.freq
                    .top_n(5)
                    .iter()
                    .map(|(v, c)| freq_entry(v, *c))
                    .collect(),
            )
        } else {
            None
        };

        let top5_least_frequent = if show_freq {
            Some(
                acc.freq
                    .bottom_n(5)
                    .iter()
                    .map(|(v, c)| freq_entry(v, *c))
                    .collect(),
            )
        } else {
            None
        };

        let histogram = if self.options.histogram && show_freq {
            let mut bins = acc.freq.histogram();
            bins.truncate(self.options.max_histogram_bins);
            Some(bins.iter().map(|(v, c)| freq_entry(v, *c)).collect())
        } else {
            None
        };

        // String lengths (text columns).
        let (str_min_len, str_max_len) = if col_type == ColumnType::Text {
            let mn = if acc.str_min_len == usize::MAX { None } else { Some(acc.str_min_len) };
            (mn, Some(acc.str_max_len))
        } else {
            (None, None)
        };

        // Warnings.
        let mut warnings = Vec::new();
        if acc.is_constant() {
            warnings.push("Constant column — all non-null values are identical".to_string());
        }
        if acc.has_mixed_types() {
            warnings.push(
                "Mixed types detected — column contains both numeric and non-numeric values"
                    .to_string(),
            );
        }
        if col_type == ColumnType::Categorical && unique_count <= 5 {
            warnings.push(format!(
                "Low-cardinality categorical — only {} distinct values",
                unique_count
            ));
        }
        if acc.null_pct() > 30.0 {
            warnings.push(format!(
                "High null rate — {:.1}% of rows are empty",
                acc.null_pct()
            ));
        }

        // Outlier detection for numeric columns (simple IQR-based heuristic).
        if matches!(col_type, ColumnType::Integer | ColumnType::Float) {
            if let (Some(q1), Some(q3)) = (acc.stats.percentile(25.0), acc.stats.percentile(75.0))
            {
                let iqr = q3 - q1;
                let lo = q1 - 1.5 * iqr;
                let hi = q3 + 1.5 * iqr;
                if acc.stats.min < lo || acc.stats.max > hi {
                    warnings.push(format!(
                        "Potential outliers detected (IQR fence: [{:.3}, {:.3}], observed range: [{:.3}, {:.3}])",
                        lo, hi, acc.stats.min, acc.stats.max
                    ));
                }
            }
        }

        let acc_name = acc.name.clone();
        let acc_row_count = acc.row_count;
        let acc_null_count = acc.null_count;
        let acc_null_pct = acc.null_pct();
        let acc_unique_exact = !acc.unique_tracker.is_overflowed();

        ColumnReport {
            name: acc_name,
            inferred_type: col_type.to_string(),
            row_count: acc_row_count,
            null_count: acc_null_count,
            null_pct: acc_null_pct,
            unique_count: Some(unique_count),
            unique_count_exact: acc_unique_exact,
            min: min_s,
            max: max_s,
            mean,
            median,
            std_dev,
            p5,
            p25,
            p75,
            p95,
            top5_most_frequent,
            top5_least_frequent,
            histogram,
            str_min_len,
            str_max_len,
            warnings,
        }
    }
}

fn format_numeric(v: f64) -> String {
    if v.fract() == 0.0 && v.abs() < 1e15 {
        format!("{:.0}", v)
    } else {
        format!("{:.6}", v)
    }
}