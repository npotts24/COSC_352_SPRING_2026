use serde::Serialize;
use std::collections::HashMap;
use std::fmt;

// ---------------------------------------------------------------------------
// Inferred column type
// ---------------------------------------------------------------------------

/// The data type inferred for a column after scanning all of its values.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum ColumnType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

impl fmt::Display for ColumnType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Integer => write!(f, "integer"),
            Self::Float => write!(f, "float"),
            Self::Boolean => write!(f, "boolean"),
            Self::Date => write!(f, "date"),
            Self::Categorical => write!(f, "categorical"),
            Self::Text => write!(f, "text"),
        }
    }
}

// ---------------------------------------------------------------------------
// Per-column profile
// ---------------------------------------------------------------------------

/// Complete statistical profile of a single column.
#[derive(Debug, Clone, Serialize)]
pub struct ColumnProfile {
    pub name: String,
    pub inferred_type: ColumnType,
    pub row_count: usize,
    pub null_count: usize,
    pub null_percent: f64,
    pub unique_count: usize,

    // Numeric stats (Integer / Float)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub min_numeric: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_numeric: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mean: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub median: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub std_dev: Option<f64>,

    // Percentiles (opt-in)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p5: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p25: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p75: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub p95: Option<f64>,

    // Date stats
    #[serde(skip_serializing_if = "Option::is_none")]
    pub min_date: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_date: Option<String>,

    // String length stats (Text)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub shortest_length: Option<usize>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub longest_length: Option<usize>,

    // Frequency tables (Categorical / Boolean)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub top_values: Option<Vec<(String, usize)>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bottom_values: Option<Vec<(String, usize)>>,

    // Histogram (opt-in)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub histogram: Option<Vec<(String, usize)>>,

    // Warnings
    pub warnings: Vec<String>,
}

impl ColumnProfile {
    pub fn new(name: String) -> Self {
        Self {
            name,
            inferred_type: ColumnType::Text,
            row_count: 0,
            null_count: 0,
            null_percent: 0.0,
            unique_count: 0,
            min_numeric: None,
            max_numeric: None,
            mean: None,
            median: None,
            std_dev: None,
            p5: None,
            p25: None,
            p75: None,
            p95: None,
            min_date: None,
            max_date: None,
            shortest_length: None,
            longest_length: None,
            top_values: None,
            bottom_values: None,
            histogram: None,
            warnings: Vec::new(),
        }
    }
}

// ---------------------------------------------------------------------------
// Whole-file profile
// ---------------------------------------------------------------------------

/// Profile of the entire CSV file.
#[derive(Debug, Clone, Serialize)]
pub struct FileProfile {
    pub file_name: String,
    pub total_rows: usize,
    pub total_columns: usize,
    pub columns: Vec<ColumnProfile>,
}

// ---------------------------------------------------------------------------
// Accumulator trait — the extensibility point
// ---------------------------------------------------------------------------

/// Trait implemented by each type-specific statistics accumulator.
///
/// `Accumulator` follows the *strategy* pattern: the profiler creates the
/// right accumulator once the column type is known and then feeds every
/// non-null value through `observe`. After the streaming pass `finalize`
/// computes the final statistics.
pub trait Accumulator: Send {
    /// Observe a single non-null, non-empty string value.
    fn observe(&mut self, value: &str);

    /// Called once after all rows have been streamed.
    /// Writes computed statistics into `profile`.
    fn finalize(&mut self, profile: &mut ColumnProfile, percentiles: bool, histogram: bool, top_n: usize);
}

// ---------------------------------------------------------------------------
// Helper: candidate type votes used during the inference pass
// ---------------------------------------------------------------------------

/// Tallies of how many non-null values parsed successfully as each candidate
/// type. Used by `infer::infer_column_type`.
#[derive(Debug, Default, Clone)]
pub struct TypeVotes {
    pub total_non_null: usize,
    pub integer: usize,
    pub float: usize,
    pub boolean: usize,
    pub date: usize,
    pub unique_values: HashMap<String, usize>,
}