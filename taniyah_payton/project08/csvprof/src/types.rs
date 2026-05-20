use chrono::NaiveDate;

/// The inferred data type for a column, determined by scanning all non-null values.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum ColumnType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

impl std::fmt::Display for ColumnType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ColumnType::Integer => write!(f, "Integer"),
            ColumnType::Float => write!(f, "Float"),
            ColumnType::Boolean => write!(f, "Boolean"),
            ColumnType::Date => write!(f, "Date"),
            ColumnType::Categorical => write!(f, "Categorical"),
            ColumnType::Text => write!(f, "Text"),
        }
    }
}

/// Date formats we try when inferring date columns.
const DATE_FORMATS: &[&str] = &[
    "%Y-%m-%d",
    "%d/%m/%Y",
    "%m/%d/%Y",
    "%Y/%m/%d",
    "%d-%m-%Y",
    "%B %d, %Y",
    "%b %d, %Y",
];

/// Returns true if the value looks like a boolean.
pub fn is_boolean(s: &str) -> bool {
    matches!(
        s.to_lowercase().trim(),
        "true" | "false" | "yes" | "no" | "1" | "0" | "t" | "f" | "y" | "n"
    )
}

/// Returns true if the value parses as an integer.
pub fn is_integer(s: &str) -> bool {
    s.trim().parse::<i64>().is_ok()
}

/// Returns true if the value parses as a float.
pub fn is_float(s: &str) -> bool {
    s.trim().parse::<f64>().is_ok()
}

/// Returns true if the value matches any of our known date formats.
pub fn is_date(s: &str) -> bool {
    let s = s.trim();
    DATE_FORMATS
        .iter()
        .any(|fmt| NaiveDate::parse_from_str(s, fmt).is_ok())
}

/// Null sentinel values — treated as missing data.
pub fn is_null(s: &str) -> bool {
    matches!(
        s.trim().to_lowercase().as_str(),
        "" | "null" | "na" | "n/a" | "nan" | "none" | "nil" | "#n/a"
    )
}

/// Infers the best `ColumnType` for a batch of raw string values.
/// Values that are null are ignored; mixed types degrade toward Text.
pub fn infer_type(values: &[String]) -> ColumnType {
    let non_null: Vec<&str> = values
        .iter()
        .filter(|v| !is_null(v))
        .map(|v| v.as_str())
        .collect();

    if non_null.is_empty() {
        return ColumnType::Text; // all-null: default to text
    }

    // Precedence: Boolean > Integer > Float > Date > Categorical / Text
    let all_bool = non_null.iter().all(|v| is_boolean(v));
    if all_bool {
        return ColumnType::Boolean;
    }

    let all_int = non_null.iter().all(|v| is_integer(v));
    if all_int {
        return ColumnType::Integer;
    }

    let all_float = non_null.iter().all(|v| is_float(v));
    if all_float {
        return ColumnType::Float;
    }

    let all_date = non_null.iter().all(|v| is_date(v));
    if all_date {
        return ColumnType::Date;
    }

    // Use cardinality heuristic: if unique ratio is low, treat as categorical.
    let unique: std::collections::HashSet<&str> = non_null.iter().copied().collect();
    let unique_ratio = unique.len() as f64 / non_null.len() as f64;
    let max_len = non_null.iter().map(|v| v.len()).max().unwrap_or(0);

    // Categorical: low cardinality OR short values with many repeats
    if unique.len() <= 50 || (unique_ratio < 0.1 && max_len <= 64) {
        return ColumnType::Categorical;
    }

    ColumnType::Text
}
