//! Report data structures for column profiling.

use serde::{Deserialize, Serialize};

/// Complete report for a single column.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ColumnReport {
    /// Column name from header (or index if no header)
    pub name: String,

    /// Inferred data type
    pub inferred_type: String,

    /// Total number of rows processed
    pub row_count: usize,

    /// Number of null/empty values
    pub null_count: usize,

    /// Percentage of null values
    pub null_pct: f64,

    /// Number of unique non-null values
    pub unique_count: usize,

    /// Whether all non-null values are identical
    pub is_constant: bool,

    /// Warning flag for inconsistent type inference
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mixed_type_warning: Option<String>,

    /// Numeric statistics (if applicable)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub numeric_stats: Option<NumericStats>,

    /// Categorical statistics (if applicable)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub categorical_stats: Option<CategoricalStats>,

    /// Text statistics (if applicable)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text_stats: Option<TextStats>,

    /// Date statistics (if applicable)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub date_stats: Option<DateStats>,
}

/// Statistics for numeric columns (Integer and Float).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NumericStats {
    /// Minimum value
    pub min: f64,

    /// Maximum value
    pub max: f64,

    /// Mean/average value using Welford's algorithm
    pub mean: f64,

    /// Median value
    pub median: f64,

    /// Standard deviation
    pub std_dev: f64,

    /// 5th percentile (if requested)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p5: Option<f64>,

    /// 25th percentile (if requested)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p25: Option<f64>,

    /// 75th percentile (if requested)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p75: Option<f64>,

    /// 95th percentile (if requested)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p95: Option<f64>,
}

/// Statistics for categorical columns.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoricalStats {
    /// Top N most frequent values with counts
    pub top_values: Vec<(String, usize)>,

    /// Bottom N least frequent values with counts (if requested)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bottom_values: Option<Vec<(String, usize)>>,

    /// Histogram data for ASCII rendering (if requested)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub histogram: Option<Vec<(String, usize)>>,
}

/// Statistics for text columns.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextStats {
    /// Minimum string length in characters
    pub min_length: usize,

    /// Maximum string length in characters
    pub max_length: usize,

    /// Average string length
    pub avg_length: f64,
}

/// Statistics for date columns.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DateStats {
    /// Earliest date found
    #[serde(skip_serializing_if = "Option::is_none")]
    pub min_date: Option<String>,

    /// Latest date found
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_date: Option<String>,

    /// Number of unique dates
    pub unique_count: usize,
}

/// Overall CSV file report.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CsvReport {
    /// File path or "stdin"
    pub file: String,

    /// Total rows processed
    pub rows: usize,

    /// Total columns
    pub columns: usize,

    /// Report for each column
    pub column_reports: Vec<ColumnReport>,
}
