use serde::Serialize;

/// The inferred semantic type of a column.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum InferredType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

impl std::fmt::Display for InferredType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            InferredType::Integer     => "Integer",
            InferredType::Float       => "Float",
            InferredType::Boolean     => "Boolean",
            InferredType::Date        => "Date",
            InferredType::Categorical => "Categorical",
            InferredType::Text        => "Text",
        };
        write!(f, "{}", s)
    }
}

/// Statistics that only make sense for numeric columns.
#[derive(Debug, Serialize)]
pub struct NumericStats {
    pub min: f64,
    pub max: f64,
    pub mean: f64,
    pub median: f64,
    pub std_dev: f64,
    /// Extended percentiles, populated only with --percentiles flag.
    pub p5:  Option<f64>,
    pub p25: Option<f64>,
    pub p75: Option<f64>,
    pub p95: Option<f64>,
}

/// Statistics that only make sense for text columns.
#[derive(Debug, Serialize)]
pub struct TextStats {
    pub min_length: usize,
    pub max_length: usize,
    pub avg_length: f64,
}

/// Statistics for categorical / boolean columns.
#[derive(Debug, Serialize)]
pub struct CategoricalStats {
    pub top_5_most_frequent:  Vec<(String, u64)>,
    pub top_5_least_frequent: Vec<(String, u64)>,
    /// Full histogram, populated only with --histogram flag.
    pub histogram: Option<Vec<(String, u64)>>,
}

/// The complete profile for a single column.
#[derive(Debug, Serialize)]
pub struct ColumnProfile {
    pub name:          String,
    pub inferred_type: InferredType,
    pub row_count:     u64,
    pub null_count:    u64,
    pub null_pct:      f64,
    pub unique_count:  u64,
    pub warnings:      Vec<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub numeric_stats:     Option<NumericStats>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub text_stats:        Option<TextStats>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub categorical_stats: Option<CategoricalStats>,
}

/// Top-level profiling result for the whole file.
#[derive(Debug, Serialize)]
pub struct FileProfile {
    pub file:         String,
    pub total_rows:   u64,
    pub total_cols:   usize,
    pub columns:      Vec<ColumnProfile>,
}
