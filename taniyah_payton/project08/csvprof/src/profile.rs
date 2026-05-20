use indexmap::IndexMap;
use serde::Serialize;

use crate::types::ColumnType;

// ── Per-type statistics payloads ──────────────────────────────────────────────

#[derive(Debug, Clone, Serialize)]
pub struct NumericStats {
    pub min: f64,
    pub max: f64,
    pub mean: f64,
    pub median: f64,
    pub std_dev: f64,
    // Optional percentiles
    pub p5: Option<f64>,
    pub p25: Option<f64>,
    pub p75: Option<f64>,
    pub p95: Option<f64>,
    pub outlier_count: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct DateStats {
    pub min: String,
    pub max: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct CategoricalStats {
    pub top5_most_frequent: Vec<(String, usize)>,
    pub top5_least_frequent: Vec<(String, usize)>,
    /// Only populated when --histogram flag is set
    pub histogram: Option<IndexMap<String, usize>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TextStats {
    pub min_length: usize,
    pub max_length: usize,
    pub avg_length: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct BooleanStats {
    pub true_count: usize,
    pub false_count: usize,
    pub top5_most_frequent: Vec<(String, usize)>,
}

/// Type-specific statistics, discriminated by column type.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum TypeStats {
    Numeric(NumericStats),
    Date(DateStats),
    Categorical(CategoricalStats),
    Text(TextStats),
    Boolean(BooleanStats),
}

// ── Warnings ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Warning {
    /// Column has only one distinct non-null value.
    ConstantColumn,
    /// Some values parsed as multiple incompatible types.
    MixedTypes { types_seen: Vec<String> },
    /// High proportion of nulls.
    HighNullRate { null_pct: f64 },
    /// Categorical column with very few distinct values.
    LowCardinality { unique_count: usize },
}

impl std::fmt::Display for Warning {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Warning::ConstantColumn => write!(f, "Constant column — only one distinct value"),
            Warning::MixedTypes { types_seen } => {
                write!(f, "Mixed types detected: {}", types_seen.join(", "))
            }
            Warning::HighNullRate { null_pct } => {
                write!(f, "High null rate: {:.1}%", null_pct)
            }
            Warning::LowCardinality { unique_count } => {
                write!(f, "Low cardinality: {} unique values", unique_count)
            }
        }
    }
}

// ── Full column profile ───────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize)]
pub struct ColumnProfile {
    pub name: String,
    pub inferred_type: ColumnType,
    pub row_count: usize,
    pub null_count: usize,
    pub null_pct: f64,
    pub unique_count: usize,
    pub type_stats: Option<TypeStats>,
    pub warnings: Vec<Warning>,
}

// ── Profiler trait ────────────────────────────────────────────────────────────

/// Any type that knows how to produce a `ColumnProfile` from raw string data
/// implements `Profiler`. This enables adding new column-type analysers
/// without touching existing code (open-closed principle).
pub trait Profiler {
    fn profile(
        &self,
        name: &str,
        values: &[String],
        inferred_type: ColumnType,
        opts: &ProfilerOptions,
    ) -> ColumnProfile;
}

/// Options forwarded to every profiler.
#[derive(Debug, Clone)]
pub struct ProfilerOptions {
    pub percentiles: bool,
    pub histogram: bool,
}
