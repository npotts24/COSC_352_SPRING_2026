use serde::{Deserialize, Serialize};

/// The inferred data type for a column.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ColumnType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
    Unknown,
}

impl std::fmt::Display for ColumnType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            ColumnType::Integer => "Integer",
            ColumnType::Float => "Float",
            ColumnType::Boolean => "Boolean",
            ColumnType::Date => "Date",
            ColumnType::Categorical => "Categorical",
            ColumnType::Text => "Text",
            ColumnType::Unknown => "Unknown",
        };
        write!(f, "{}", s)
    }
}

/// Tracks how many values in a column successfully parse as each type.
#[derive(Debug, Default)]
pub struct TypeVotes {
    pub integer: usize,
    pub float: usize,
    pub boolean: usize,
    pub date: usize,
    pub non_null: usize,
}

/// Date patterns we recognise during inference.
static DATE_PATTERNS: &[&str] = &[
    r"^\d{4}-\d{2}-\d{2}$",
    r"^\d{2}/\d{2}/\d{4}$",
    r"^\d{2}-\d{2}-\d{4}$",
    r"^\d{4}/\d{2}/\d{2}$",
];

pub fn looks_like_date(value: &str) -> bool {
    use regex::Regex;
    // Build lazily each call — acceptable for inference phase
    DATE_PATTERNS
        .iter()
        .any(|pat| Regex::new(pat).map(|re| re.is_match(value)).unwrap_or(false))
}

pub fn looks_like_boolean(value: &str) -> bool {
    matches!(
        value.to_ascii_lowercase().as_str(),
        "true" | "false" | "yes" | "no" | "1" | "0" | "t" | "f" | "y" | "n"
    )
}

impl TypeVotes {
    pub fn observe(&mut self, value: &str) {
        self.non_null += 1;
        if value.parse::<i64>().is_ok() {
            self.integer += 1;
        }
        if value.parse::<f64>().is_ok() {
            self.float += 1;
        }
        if looks_like_boolean(value) {
            self.boolean += 1;
        }
        if looks_like_date(value) {
            self.date += 1;
        }
    }

    /// Decide the column type given accumulated votes and cardinality info.
    pub fn resolve(
        &self,
        unique_count: usize,
        total_non_null: usize,
        categorical_threshold: f64,
    ) -> ColumnType {
        if total_non_null == 0 {
            return ColumnType::Unknown;
        }

        let match_ratio = |votes: usize| votes as f64 / total_non_null as f64;

        if match_ratio(self.boolean) >= 0.95 {
            return ColumnType::Boolean;
        }
        if match_ratio(self.date) >= 0.90 {
            return ColumnType::Date;
        }
        if match_ratio(self.integer) >= 0.95 {
            return ColumnType::Integer;
        }
        if match_ratio(self.float) >= 0.90 {
            return ColumnType::Float;
        }

        // Categorical: low-cardinality relative to row count
        let cardinality_ratio = unique_count as f64 / total_non_null as f64;
        if cardinality_ratio <= categorical_threshold {
            return ColumnType::Categorical;
        }

        ColumnType::Text
    }
}