use chrono::{NaiveDate, NaiveDateTime};
use serde::Serialize;
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, Serialize)]
pub enum InferredType {
    Empty,
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

#[derive(Debug, Clone)]
pub struct ColumnProfile {
    pub name: String,

    pub row_count: u64,
    pub null_count: u64,

    pub unique_values: HashSet<String>,
    pub frequencies: HashMap<String, u64>,

    pub numeric_values: Vec<f64>,
    pub date_values: Vec<NaiveDate>,

    pub numeric_seen: u64,
    pub integer_seen: u64,
    pub float_seen: u64,
    pub boolean_seen: u64,
    pub date_seen: u64,
    pub text_seen: u64,

    pub shortest_len: Option<usize>,
    pub longest_len: Option<usize>,
}

#[derive(Debug, Clone, Serialize)]
pub struct NumericSummary {
    pub min: f64,
    pub max: f64,
    pub mean: f64,
    pub median: f64,
    pub std_dev: f64,
    pub p5: Option<f64>,
    pub p25: Option<f64>,
    pub p75: Option<f64>,
    pub p95: Option<f64>,
    pub outlier_count: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct DateSummary {
    pub min: String,
    pub max: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct TextSummary {
    pub shortest_len: usize,
    pub longest_len: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct FrequencyEntry {
    pub value: String,
    pub count: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct ColumnSummary {
    pub name: String,
    pub inferred_type: InferredType,
    pub row_count: u64,
    pub null_count: u64,
    pub null_percent: f64,
    pub unique_count: usize,
    pub mixed_type_warning: bool,
    pub constant_column_warning: bool,
    pub numeric: Option<NumericSummary>,
    pub date: Option<DateSummary>,
    pub text: Option<TextSummary>,
    pub top_5_most_frequent: Option<Vec<FrequencyEntry>>,
    pub top_5_least_frequent: Option<Vec<FrequencyEntry>>,
    pub histogram: Option<Vec<FrequencyEntry>>,
}

impl ColumnProfile {
    pub fn new(name: String) -> Self {
        Self {
            name,
            row_count: 0,
            null_count: 0,
            unique_values: HashSet::new(),
            frequencies: HashMap::new(),
            numeric_values: Vec::new(),
            date_values: Vec::new(),
            numeric_seen: 0,
            integer_seen: 0,
            float_seen: 0,
            boolean_seen: 0,
            date_seen: 0,
            text_seen: 0,
            shortest_len: None,
            longest_len: None,
        }
    }

    pub fn update(&mut self, raw: &str) {
        self.row_count += 1;

        let value = raw.trim();
        if is_null_like(value) {
            self.null_count += 1;
            return;
        }

        self.unique_values.insert(value.to_string());
        *self.frequencies.entry(value.to_string()).or_insert(0) += 1;

        if let Ok(n) = value.parse::<i64>() {
            self.numeric_seen += 1;
            self.integer_seen += 1;
            self.numeric_values.push(n as f64);
            return;
        }

        if let Ok(n) = value.parse::<f64>() {
            self.numeric_seen += 1;
            self.float_seen += 1;
            self.numeric_values.push(n);
            return;
        }

        if parse_bool(value).is_some() {
            self.boolean_seen += 1;
            return;
        }

        if let Some(d) = parse_date(value) {
            self.date_seen += 1;
            self.date_values.push(d);
            return;
        }

        self.text_seen += 1;
        let len = value.chars().count();
        self.shortest_len = Some(self.shortest_len.map_or(len, |x| x.min(len)));
        self.longest_len = Some(self.longest_len.map_or(len, |x| x.max(len)));
    }

    pub fn finalize(
        &self,
        percentiles: bool,
        histogram: bool,
        max_categories: usize,
        categorical_ratio: f64,
    ) -> ColumnSummary {
        let non_null = self.row_count.saturating_sub(self.null_count);
        let unique_count = self.unique_values.len();

        let inferred_type =
            self.infer_type(non_null, unique_count, max_categories, categorical_ratio);
        let mixed_type_warning = self.mixed_type_warning();
        let constant_column_warning = non_null > 0 && unique_count == 1;

        let numeric = match inferred_type {
            InferredType::Integer | InferredType::Float => Some(self.numeric_summary(percentiles)),
            _ => None,
        };

        let date = match inferred_type {
            InferredType::Date => self.date_summary(),
            _ => None,
        };

        let text = match inferred_type {
            InferredType::Text => self.text_summary(),
            _ => None,
        };

        let (top_5_most_frequent, top_5_least_frequent, histogram_values) = match inferred_type {
            InferredType::Categorical | InferredType::Boolean => {
                let most = Some(self.top_n_frequent(5, true));
                let least = Some(self.top_n_frequent(5, false));
                let hist = if histogram {
                    Some(self.histogram_entries())
                } else {
                    None
                };
                (most, least, hist)
            }
            _ => (None, None, None),
        };

        ColumnSummary {
            name: self.name.clone(),
            inferred_type,
            row_count: self.row_count,
            null_count: self.null_count,
            null_percent: if self.row_count == 0 {
                0.0
            } else {
                (self.null_count as f64 / self.row_count as f64) * 100.0
            },
            unique_count,
            mixed_type_warning,
            constant_column_warning,
            numeric,
            date,
            text,
            top_5_most_frequent,
            top_5_least_frequent,
            histogram: histogram_values,
        }
    }

    fn infer_type(
        &self,
        non_null: u64,
        unique_count: usize,
        max_categories: usize,
        categorical_ratio: f64,
    ) -> InferredType {
        if non_null == 0 {
            return InferredType::Empty;
        }

        if self.numeric_seen == non_null {
            if self.float_seen == 0 {
                return InferredType::Integer;
            }
            return InferredType::Float;
        }

        if self.boolean_seen == non_null {
            return InferredType::Boolean;
        }

        if self.date_seen == non_null {
            return InferredType::Date;
        }

        let ratio = unique_count as f64 / non_null as f64;
        if unique_count <= max_categories || ratio <= categorical_ratio {
            return InferredType::Categorical;
        }

        InferredType::Text
    }

    fn mixed_type_warning(&self) -> bool {
        let mut families = 0;
        if self.numeric_seen > 0 {
            families += 1;
        }
        if self.boolean_seen > 0 {
            families += 1;
        }
        if self.date_seen > 0 {
            families += 1;
        }
        if self.text_seen > 0 {
            families += 1;
        }
        families > 1
    }

    fn numeric_summary(&self, percentiles: bool) -> NumericSummary {
        let mut values = self.numeric_values.clone();
        values.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let n = values.len() as f64;
        let min = *values.first().unwrap_or(&0.0);
        let max = *values.last().unwrap_or(&0.0);
        let mean = if values.is_empty() {
            0.0
        } else {
            values.iter().sum::<f64>() / n
        };

        let median = percentile_from_sorted(&values, 50.0).unwrap_or(0.0);

        let variance = if values.len() > 1 {
            values
                .iter()
                .map(|v| {
                    let d = *v - mean;
                    d * d
                })
                .sum::<f64>()
                / (n - 1.0)
        } else {
            0.0
        };
        let std_dev = variance.sqrt();

        let p25 = percentile_from_sorted(&values, 25.0);
        let p75 = percentile_from_sorted(&values, 75.0);

        let outlier_count = if let (Some(q1), Some(q3)) = (p25, p75) {
            let iqr = q3 - q1;
            let low = q1 - 1.5 * iqr;
            let high = q3 + 1.5 * iqr;
            values.iter().filter(|v| **v < low || **v > high).count()
        } else {
            0
        };

        NumericSummary {
            min,
            max,
            mean,
            median,
            std_dev,
            p5: if percentiles {
                percentile_from_sorted(&values, 5.0)
            } else {
                None
            },
            p25: if percentiles { p25 } else { None },
            p75: if percentiles { p75 } else { None },
            p95: if percentiles {
                percentile_from_sorted(&values, 95.0)
            } else {
                None
            },
            outlier_count,
        }
    }

    fn date_summary(&self) -> Option<DateSummary> {
        if self.date_values.is_empty() {
            return None;
        }

        let min = self.date_values.iter().min()?.to_string();
        let max = self.date_values.iter().max()?.to_string();

        Some(DateSummary { min, max })
    }

    fn text_summary(&self) -> Option<TextSummary> {
        Some(TextSummary {
            shortest_len: self.shortest_len?,
            longest_len: self.longest_len?,
        })
    }

    fn top_n_frequent(&self, n: usize, descending: bool) -> Vec<FrequencyEntry> {
        let mut items: Vec<(String, u64)> = self
            .frequencies
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();

        if descending {
            items.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
        } else {
            items.sort_by(|a, b| a.1.cmp(&b.1).then_with(|| a.0.cmp(&b.0)));
        }

        items
            .into_iter()
            .take(n)
            .map(|(value, count)| FrequencyEntry { value, count })
            .collect()
    }

    fn histogram_entries(&self) -> Vec<FrequencyEntry> {
        let mut items: Vec<(String, u64)> = self
            .frequencies
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();

        items.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));

        items
            .into_iter()
            .map(|(value, count)| FrequencyEntry { value, count })
            .collect()
    }
}

fn is_null_like(value: &str) -> bool {
    value.is_empty()
        || matches!(
            value.to_ascii_lowercase().as_str(),
            "na" | "n/a" | "null" | "none" | "nan"
        )
}

fn parse_bool(value: &str) -> Option<bool> {
    match value.to_ascii_lowercase().as_str() {
        "true" | "yes" | "y" => Some(true),
        "false" | "no" | "n" => Some(false),
        _ => None,
    }
}

fn parse_date(value: &str) -> Option<NaiveDate> {
    const DATE_FORMATS: &[&str] = &[
        "%Y-%m-%d", "%Y/%m/%d", "%m/%d/%Y", "%d/%m/%Y", "%m-%d-%Y", "%d-%m-%Y",
    ];

    for fmt in DATE_FORMATS {
        if let Ok(d) = NaiveDate::parse_from_str(value, fmt) {
            return Some(d);
        }
    }

    const DATETIME_FORMATS: &[&str] = &[
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%m/%d/%Y %H:%M:%S",
    ];

    for fmt in DATETIME_FORMATS {
        if let Ok(dt) = NaiveDateTime::parse_from_str(value, fmt) {
            return Some(dt.date());
        }
    }

    None
}

fn percentile_from_sorted(values: &[f64], p: f64) -> Option<f64> {
    if values.is_empty() {
        return None;
    }
    let rank = (p / 100.0) * (values.len() - 1) as f64;
    let low = rank.floor() as usize;
    let high = rank.ceil() as usize;

    if low == high {
        Some(values[low])
    } else {
        let weight = rank - low as f64;
        Some(values[low] * (1.0 - weight) + values[high] * weight)
    }
}
