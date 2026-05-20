/// Core type definitions used throughout csvprof.
use std::fmt;

/// The inferred data type for a column.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum InferredType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

impl fmt::Display for InferredType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            InferredType::Integer => write!(f, "Integer"),
            InferredType::Float => write!(f, "Float"),
            InferredType::Boolean => write!(f, "Boolean"),
            InferredType::Date => write!(f, "Date"),
            InferredType::Categorical => write!(f, "Categorical"),
            InferredType::Text => write!(f, "Text"),
        }
    }
}

/// Complete statistical profile for a single column.
#[derive(Debug)]
pub struct ColumnProfile {
    pub name: String,
    pub inferred_type: InferredType,
    pub row_count: usize,
    pub null_count: usize,
    pub unique_count: usize,
    pub numeric_stats: Option<NumericStats>,
    pub date_stats: Option<DateStats>,
    pub text_stats: Option<TextStats>,
    pub categorical_stats: Option<CategoricalStats>,
    pub quality: QualityFlags,
}

/// Statistics for numeric columns (Integer or Float).
#[derive(Debug, Clone)]
pub struct NumericStats {
    pub min: f64,
    pub max: f64,
    pub mean: f64,
    pub median: f64,
    pub std_dev: f64,
    pub percentiles: Option<Percentiles>,
}

/// Percentile values for numeric columns.
#[derive(Debug, Clone)]
pub struct Percentiles {
    pub p5: f64,
    pub p25: f64,
    pub p75: f64,
    pub p95: f64,
}

/// Statistics for date columns.
#[derive(Debug, Clone)]
pub struct DateStats {
    pub min: chrono::NaiveDate,
    pub max: chrono::NaiveDate,
}

/// Statistics for text columns.
#[derive(Debug, Clone)]
pub struct TextStats {
    pub min_length: usize,
    pub max_length: usize,
}

/// Frequency entry for categorical / boolean columns.
#[derive(Debug, Clone)]
pub struct FrequencyEntry {
    pub value: String,
    pub count: usize,
}

/// Statistics for categorical / boolean columns.
#[derive(Debug, Clone)]
pub struct CategoricalStats {
    pub top_5_most: Vec<FrequencyEntry>,
    pub top_5_least: Vec<FrequencyEntry>,
    pub histogram: Option<Vec<FrequencyEntry>>,
}

/// Data quality flags detected for a column.
#[derive(Debug, Default)]
pub struct QualityFlags {
    pub has_mixed_types: bool,
    pub is_constant: bool,
    pub high_null_pct: bool,
    pub outlier_count: Option<usize>,
    pub low_cardinality: bool,
}
