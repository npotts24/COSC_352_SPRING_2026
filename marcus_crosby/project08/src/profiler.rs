use std::collections::HashSet;
use std::io::Read;

use anyhow::Context;
use chrono::{DateTime, NaiveDate, NaiveDateTime};
use csv::{ReaderBuilder, StringRecord};

use crate::stats::{
    BoolColumnStats, CategoricalColumnStats, ColumnStats, DateColumnStats, DateStats,
    FrequencyAccumulator, LexicalStats, NumericAccumulator, NumericColumnStats, NumericStats,
    TextColumnStats,
};
use crate::types::{ColumnReport, DatasetReport, InferredType};

#[derive(Debug, Clone)]
pub struct ProfilerConfig {
    pub delimiter: u8,
    pub has_headers: bool,
    pub top_k: usize,
    pub top_k_capacity: usize,
    pub distinct_capacity: usize,
    pub sample_size: usize,
    pub percentiles: Vec<f64>,
    pub null_values: HashSet<String>,
}

#[derive(Debug)]
pub struct Profiler {
    config: ProfilerConfig,
    rows: u64,
    columns: Vec<ColumnAccumulator>,
}

impl Profiler {
    pub fn new(config: ProfilerConfig) -> Self {
        Self {
            config,
            rows: 0,
            columns: Vec::new(),
        }
    }

    pub fn initialize_headers(&mut self, headers: &StringRecord) {
        if self.columns.is_empty() {
            self.columns = headers
                .iter()
                .enumerate()
                .map(|(index, header)| {
                    ColumnAccumulator::new(header.to_string(), index, 0, &self.config)
                })
                .collect();
        }
    }

    pub fn profile_reader<R: Read>(&mut self, reader: R) -> anyhow::Result<()> {
        let mut csv_reader = ReaderBuilder::new()
            .delimiter(self.config.delimiter)
            .has_headers(self.config.has_headers)
            .flexible(true)
            .from_reader(reader);

        if self.config.has_headers {
            let headers = csv_reader
                .headers()
                .context("failed to read CSV headers")?
                .clone();
            self.initialize_headers(&headers);
        }

        for record in csv_reader.records() {
            let record = record.context("failed to read CSV record")?;
            self.update_record(&record);
        }

        Ok(())
    }

    pub fn update_record(&mut self, record: &StringRecord) {
        self.rows += 1;

        if record.len() > self.columns.len() {
            let start = self.columns.len();
            self.columns.extend((start..record.len()).map(|index| {
                ColumnAccumulator::new(
                    default_column_name(index),
                    index,
                    self.rows.saturating_sub(1),
                    &self.config,
                )
            }));
        }

        for index in 0..self.columns.len() {
            let value = record.get(index).unwrap_or("");
            self.columns[index].update(value, &self.config);
        }
    }

    pub fn finalize(self) -> DatasetReport {
        DatasetReport {
            rows: self.rows,
            columns: self
                .columns
                .into_iter()
                .map(|column| column.finalize(self.rows, &self.config))
                .collect(),
        }
    }
}

#[derive(Debug, Clone)]
struct ColumnAccumulator {
    name: String,
    inference: TypeTracker,
    null_count: u64,
    lexical: LexicalStats,
    numeric: NumericStats,
    dates: DateStats,
    true_count: u64,
    false_count: u64,
}

impl ColumnAccumulator {
    fn new(name: String, _index: usize, initial_null_count: u64, config: &ProfilerConfig) -> Self {
        Self {
            name,
            inference: TypeTracker::default(),
            null_count: initial_null_count,
            lexical: LexicalStats::new(config.distinct_capacity, config.top_k_capacity),
            numeric: NumericStats::new(config.sample_size),
            dates: DateStats::new(),
            true_count: 0,
            false_count: 0,
        }
    }

    fn update(&mut self, raw: &str, config: &ProfilerConfig) {
        let trimmed = raw.trim();
        if is_null(trimmed, &config.null_values) {
            self.null_count += 1;
            return;
        }

        let parsed = ParsedCell::parse(trimmed);
        self.inference.observe(&parsed);
        self.lexical.update_text(trimmed);

        if let Some(value) = parsed.numeric_value() {
            self.numeric.update_numeric(value);
        }
        if let Some(value) = parsed.date {
            self.dates.update(value);
        }
        if let Some(value) = parsed.bool {
            if value {
                self.true_count += 1;
            } else {
                self.false_count += 1;
            }
        }
    }

    fn finalize(self, rows: u64, config: &ProfilerConfig) -> ColumnReport {
        let inferred_type = self.inference.final_type(&self.lexical);
        let non_null_count = rows.saturating_sub(self.null_count);

        let mut report = ColumnReport {
            name: self.name,
            inferred_type,
            rows,
            non_null_count,
            null_count: self.null_count,
            distinct_count: None,
            distinct_is_approximate: false,
            min: None,
            max: None,
            mean: None,
            median: None,
            std_dev: None,
            percentiles: Vec::new(),
            top_values: Vec::new(),
            notes: self.inference.notes(),
        };

        let strategy: Box<dyn ColumnStats> = match inferred_type {
            InferredType::Int | InferredType::Float => Box::new(NumericColumnStats::new(
                self.numeric.clone(),
                self.lexical.clone(),
            )),
            InferredType::Bool => Box::new(BoolColumnStats::new(
                self.lexical.clone(),
                self.true_count,
                self.false_count,
            )),
            InferredType::Date => Box::new(DateColumnStats::new(
                self.dates.clone(),
                self.lexical.clone(),
            )),
            InferredType::Categorical => {
                Box::new(CategoricalColumnStats::new(self.lexical.clone()))
            }
            InferredType::Text => Box::new(TextColumnStats::new(self.lexical.clone())),
        };
        strategy.finalize(
            &mut report,
            inferred_type,
            config.top_k,
            &config.percentiles,
        );

        report
    }
}

#[derive(Debug, Clone, Default)]
struct TypeTracker {
    non_null_count: u64,
    could_be_int: bool,
    could_be_float: bool,
    could_be_bool: bool,
    could_be_date: bool,
    seen_numeric: u64,
    seen_textual: u64,
    seen_mixed: bool,
}

impl TypeTracker {
    fn observe(&mut self, parsed: &ParsedCell) {
        if self.non_null_count == 0 {
            self.could_be_int = true;
            self.could_be_float = true;
            self.could_be_bool = true;
            self.could_be_date = true;
        }

        self.non_null_count += 1;

        self.could_be_int &= parsed.int.is_some();
        self.could_be_float &= parsed.float.is_some() || parsed.int.is_some();
        self.could_be_bool &= parsed.bool.is_some();
        self.could_be_date &= parsed.date.is_some();

        if parsed.numeric_value().is_some() {
            self.seen_numeric += 1;
        }
        if parsed.int.is_none()
            && parsed.float.is_none()
            && parsed.bool.is_none()
            && parsed.date.is_none()
        {
            self.seen_textual += 1;
        }
        if self.seen_numeric > 0 && self.seen_textual > 0 {
            self.seen_mixed = true;
        }
    }

    fn final_type(&self, lexical: &LexicalStats) -> InferredType {
        if self.non_null_count == 0 {
            return InferredType::Text;
        }
        if self.could_be_int {
            return InferredType::Int;
        }
        if self.could_be_float {
            return InferredType::Float;
        }
        if self.could_be_bool {
            return InferredType::Bool;
        }
        if self.could_be_date {
            return InferredType::Date;
        }
        if self.seen_mixed {
            return InferredType::Text;
        }

        let (distinct, _) = lexical.distinct_count();
        let distinct_ratio = distinct as f64 / self.non_null_count as f64;
        let avg_len = lexical.avg_len();
        if avg_len <= 48.0 && (distinct <= 32 || distinct_ratio <= 0.20) {
            InferredType::Categorical
        } else {
            InferredType::Text
        }
    }

    fn notes(&self) -> Vec<String> {
        let mut notes = Vec::new();
        if self.non_null_count == 0 {
            notes.push("column only contains null-like values".to_string());
        }
        if self.seen_mixed {
            notes
                .push("mixed numeric and free-text values prevented numeric inference".to_string());
        }
        notes
    }
}

#[derive(Debug, Clone, Copy)]
struct ParsedCell {
    int: Option<i64>,
    float: Option<f64>,
    bool: Option<bool>,
    date: Option<NaiveDateTime>,
}

impl ParsedCell {
    fn parse(raw: &str) -> Self {
        let int = raw.parse::<i64>().ok();
        let float = raw.parse::<f64>().ok().filter(|value| value.is_finite());
        let bool = parse_bool(raw);
        let date = parse_date(raw);

        Self {
            int,
            float,
            bool,
            date,
        }
    }

    fn numeric_value(&self) -> Option<f64> {
        self.int.map(|value| value as f64).or(self.float)
    }
}

fn parse_bool(raw: &str) -> Option<bool> {
    match raw.to_ascii_lowercase().as_str() {
        "true" | "t" | "yes" | "y" => Some(true),
        "false" | "f" | "no" | "n" => Some(false),
        _ => None,
    }
}

fn parse_date(raw: &str) -> Option<NaiveDateTime> {
    const DATE_FORMATS: &[&str] = &[
        "%Y-%m-%d", "%m/%d/%y", "%d/%m/%y", "%m/%d/%Y", "%d/%m/%Y", "%Y/%m/%d",
    ];
    const DATETIME_FORMATS: &[&str] = &[
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M:%S%.f",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M:%S%.f",
        "%m/%d/%y %H:%M:%S",
        "%m/%d/%Y %H:%M:%S",
    ];

    for format in DATETIME_FORMATS {
        if let Ok(value) = NaiveDateTime::parse_from_str(raw, format) {
            return Some(value);
        }
    }

    for format in DATE_FORMATS {
        if let Ok(value) = NaiveDate::parse_from_str(raw, format) {
            return value.and_hms_opt(0, 0, 0);
        }
    }

    if let Some(value) = parse_month_precision_date(raw) {
        return Some(value);
    }

    DateTime::parse_from_rfc3339(raw)
        .ok()
        .map(|value| value.naive_utc())
}

fn parse_month_precision_date(raw: &str) -> Option<NaiveDateTime> {
    let (month, year) = raw.split_once('/')?;
    let month: u32 = month.parse().ok()?;
    let year: i32 = year.parse().ok()?;
    NaiveDate::from_ymd_opt(year, month, 1)?.and_hms_opt(0, 0, 0)
}

fn is_null(raw: &str, null_values: &HashSet<String>) -> bool {
    raw.is_empty() || null_values.contains(&raw.to_ascii_lowercase())
}

fn default_column_name(index: usize) -> String {
    format!("column_{}", index + 1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn infers_float_for_int_and_float_mix() {
        let mut tracker = TypeTracker::default();
        tracker.observe(&ParsedCell::parse("1"));
        tracker.observe(&ParsedCell::parse("2.5"));
        let lexical = LexicalStats::new(128, 16);
        assert_eq!(tracker.final_type(&lexical), InferredType::Float);
    }

    #[test]
    fn infers_text_for_numeric_and_words_mix() {
        let mut tracker = TypeTracker::default();
        let mut lexical = LexicalStats::new(128, 16);
        for value in ["10", "hello"] {
            tracker.observe(&ParsedCell::parse(value));
            lexical.update_text(value);
        }
        assert_eq!(tracker.final_type(&lexical), InferredType::Text);
    }

    #[test]
    fn parses_two_digit_us_dates() {
        assert!(parse_date("07/03/25").is_some());
    }

    #[test]
    fn parses_month_precision_dates() {
        assert!(parse_date("11/2014").is_some());
    }
}
