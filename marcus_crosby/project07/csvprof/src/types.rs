use clap::ValueEnum;
use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum InferredType {
    Int,
    Float,
    Bool,
    Date,
    Categorical,
    Text,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, ValueEnum)]
pub enum OutputFormat {
    Markdown,
    Json,
}

#[derive(Debug, Clone, Serialize)]
pub struct FrequencyEntry {
    pub value: String,
    pub count: u64,
    pub ratio: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct PercentileValue {
    pub percentile: f64,
    pub value: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct ColumnReport {
    pub name: String,
    pub inferred_type: InferredType,
    pub rows: u64,
    pub non_null_count: u64,
    pub null_count: u64,
    pub distinct_count: Option<u64>,
    pub distinct_is_approximate: bool,
    pub min: Option<String>,
    pub max: Option<String>,
    pub mean: Option<f64>,
    pub median: Option<f64>,
    pub std_dev: Option<f64>,
    pub percentiles: Vec<PercentileValue>,
    pub top_values: Vec<FrequencyEntry>,
    pub notes: Vec<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct DatasetReport {
    pub rows: u64,
    pub columns: Vec<ColumnReport>,
}
