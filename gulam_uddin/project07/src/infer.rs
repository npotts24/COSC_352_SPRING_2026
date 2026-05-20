use crate::types::{ColumnType, TypeVotes};

// ---------------------------------------------------------------------------
// Individual value parsers
// ---------------------------------------------------------------------------

/// Returns `true` if `s` represents an integer (optional leading sign).
pub fn is_integer(s: &str) -> bool {
    s.parse::<i64>().is_ok()
}

/// Returns `true` if `s` represents a floating-point number.
pub fn is_float(s: &str) -> bool {
    s.parse::<f64>().is_ok()
}

/// Returns `true` if `s` is a boolean literal.
pub fn is_boolean(s: &str) -> bool {
    matches!(
        s.to_lowercase().as_str(),
        "true" | "false" | "yes" | "no" | "1" | "0" | "t" | "f" | "y" | "n"
    )
}

/// Common date formats we try when classifying a value as a date.
const DATE_FORMATS: &[&str] = &[
    "%Y-%m-%d",
    "%m/%d/%Y",
    "%d/%m/%Y",
    "%Y/%m/%d",
    "%m-%d-%Y",
    "%d-%m-%Y",
    "%Y-%m-%d %H:%M:%S",
    "%m/%d/%Y %H:%M:%S",
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%dT%H:%M:%S%.f",
    "%Y-%m-%dT%H:%M:%SZ",
    "%b %d, %Y",
    "%B %d, %Y",
    "%d %b %Y",
    "%d %B %Y",
];

/// Returns `true` if `s` can be parsed as a date with any of the known
/// formats.
pub fn is_date(s: &str) -> bool {
    DATE_FORMATS
        .iter()
        .any(|fmt| chrono::NaiveDateTime::parse_from_str(s, fmt).is_ok()
            || chrono::NaiveDate::parse_from_str(s, fmt).is_ok())
}

/// Returns `true` when the value should be treated as null / missing.
pub fn is_null(s: &str) -> bool {
    let lower = s.to_lowercase();
    s.is_empty()
        || matches!(
            lower.as_str(),
            "na" | "n/a" | "null" | "none" | "nan" | "nil" | "missing" | "-" | "."
        )
}

// ---------------------------------------------------------------------------
// Column-level inference
// ---------------------------------------------------------------------------

/// Cast the accumulated votes into a single `ColumnType`.
///
/// Priority order: boolean → integer → float → date → categorical → text.
/// A type is accepted when ≥ 85 % of non-null values match.
pub fn infer_column_type(votes: &TypeVotes, category_threshold: usize) -> ColumnType {
    let n = votes.total_non_null;
    if n == 0 {
        return ColumnType::Text;
    }
    let threshold = (n as f64 * 0.85) as usize;

    // Boolean first — very restrictive set of literals
    if votes.boolean >= threshold {
        return ColumnType::Boolean;
    }
    // Pure integers
    if votes.integer >= threshold {
        return ColumnType::Integer;
    }
    // Floats (integers also parse as floats, so check after integer)
    if votes.float >= threshold {
        return ColumnType::Float;
    }
    // Dates
    if votes.date >= threshold {
        return ColumnType::Date;
    }
    // Categorical vs free text
    let cardinality = votes.unique_values.len();
    if cardinality <= category_threshold {
        ColumnType::Categorical
    } else {
        ColumnType::Text
    }
}

/// Record one non-null value into the vote tally.
pub fn vote(votes: &mut TypeVotes, value: &str) {
    votes.total_non_null += 1;
    *votes.unique_values.entry(value.to_owned()).or_insert(0) += 1;

    if is_boolean(value) {
        votes.boolean += 1;
    }
    if is_integer(value) {
        votes.integer += 1;
    }
    if is_float(value) {
        votes.float += 1;
    }
    if is_date(value) {
        votes.date += 1;
    }
}

// ---------------------------------------------------------------------------
// Mixed-type detection
// ---------------------------------------------------------------------------

/// Returns a warning string when a column has significant representation of
/// more than one type (> 5 % each of at least two types).
pub fn mixed_type_warning(votes: &TypeVotes, inferred: ColumnType) -> Option<String> {
    let n = votes.total_non_null as f64;
    if n == 0.0 {
        return None;
    }
    let counts = [
        ("integer", votes.integer),
        ("float", votes.float),
        ("boolean", votes.boolean),
        ("date", votes.date),
    ];
    let significant: Vec<&str> = counts
        .iter()
        .filter(|(_, c)| (*c as f64 / n) > 0.05)
        .map(|(name, _)| *name)
        .collect();

    if significant.len() > 1 {
        Some(format!(
            "Mixed types detected (inferred {inferred}): significant counts for {}",
            significant.join(", ")
        ))
    } else {
        None
    }
}