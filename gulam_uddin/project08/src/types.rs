//! Data-type inference lattice.
//!
//! The profiler never commits to a type until it has seen every non-null
//! value in a column. We maintain a *lattice* of possibilities where each
//! new value narrows (or widens to `Text`) what the column could be.
//!
//! The lattice, loosely, is:
//!
//! ```text
//!              Empty
//!                |
//!         +------+------+------+--------+
//!         |      |      |      |        |
//!      Boolean Integer Float  Date   Text
//!         \      |     /       |      /
//!          \     |    /        |     /
//!           +-- Text (fallback / mixed) --+
//! ```
//!
//! `Categorical` is a *post-hoc* classification: we start as `Text` and
//! promote to `Categorical` in the report phase if cardinality is low.

use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use std::fmt;

/// The inferred logical type of a CSV column.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ColumnType {
    /// No non-null values seen yet.
    Empty,
    /// All values parse as `true`/`false`/`yes`/`no`/`0`/`1`.
    Boolean,
    /// All values parse as 64-bit signed integers.
    Integer,
    /// All values parse as f64 (and at least one has a decimal part).
    Float,
    /// All values parse as ISO-8601 calendar dates (`YYYY-MM-DD`).
    Date,
    /// Low-cardinality text — set after-the-fact.
    Categorical,
    /// Fallback for anything else, including mixed types.
    Text,
}

impl fmt::Display for ColumnType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            ColumnType::Empty       => "empty",
            ColumnType::Boolean     => "boolean",
            ColumnType::Integer     => "integer",
            ColumnType::Float       => "float",
            ColumnType::Date        => "date",
            ColumnType::Categorical => "categorical",
            ColumnType::Text        => "text",
        };
        f.write_str(s)
    }
}

impl ColumnType {
    /// True if this column carries numeric statistics.
    pub fn is_numeric(self) -> bool {
        matches!(self, ColumnType::Integer | ColumnType::Float)
    }

    /// True if ordering (min/max) is meaningful.
    pub fn is_ordered(self) -> bool {
        matches!(
            self,
            ColumnType::Integer | ColumnType::Float | ColumnType::Date
        )
    }
}

/// A single parsed cell, used by the analyzer to collect statistics
/// without repeatedly re-parsing the original string.
#[derive(Debug, Clone)]
pub enum InferredValue {
    Null,
    Bool(bool),
    Int(i64),
    Float(f64),
    Date(NaiveDate),
    Text(String),
}

impl InferredValue {
    /// Parse a raw CSV cell into the richest type we can infer *locally*.
    /// The column-level aggregation step is responsible for unifying
    /// these into a single `ColumnType`.
    pub fn parse(raw: &str) -> Self {
        let trimmed = raw.trim();
        if trimmed.is_empty()
            || trimmed.eq_ignore_ascii_case("null")
            || trimmed.eq_ignore_ascii_case("na")
            || trimmed.eq_ignore_ascii_case("n/a")
            || trimmed == "-"
        {
            return InferredValue::Null;
        }
        // Boolean check first; this is stricter than parse::<i64>() for "0"/"1"
        // so we only treat 0/1 as bool when they appear alongside explicit
        // true/false labels. We conservatively treat pure "0"/"1" as Int here.
        let lower = trimmed.to_ascii_lowercase();
        if matches!(lower.as_str(), "true" | "false" | "yes" | "no") {
            return InferredValue::Bool(matches!(lower.as_str(), "true" | "yes"));
        }
        if let Ok(n) = trimmed.parse::<i64>() {
            return InferredValue::Int(n);
        }
        if let Ok(f) = trimmed.parse::<f64>() {
            if f.is_finite() {
                return InferredValue::Float(f);
            }
        }
        // Date (only ISO calendar date; a datetime string falls through to Text).
        if trimmed.len() == 10 {
            if let Ok(d) = NaiveDate::parse_from_str(trimmed, "%Y-%m-%d") {
                return InferredValue::Date(d);
            }
        }
        InferredValue::Text(trimmed.to_owned())
    }

    /// What `ColumnType` would this single value imply by itself?
    pub fn implied_type(&self) -> ColumnType {
        match self {
            InferredValue::Null     => ColumnType::Empty,
            InferredValue::Bool(_)  => ColumnType::Boolean,
            InferredValue::Int(_)   => ColumnType::Integer,
            InferredValue::Float(_) => ColumnType::Float,
            InferredValue::Date(_)  => ColumnType::Date,
            InferredValue::Text(_)  => ColumnType::Text,
        }
    }
}

/// Narrow two possibilities down to the tightest common type.
///
/// Rules:
/// - Empty unifies with anything (returns the other).
/// - Integer ∨ Float ⇒ Float.
/// - Any conflict falls back to Text (this is how we surface "mixed
///   type" warnings downstream).
pub fn unify(a: ColumnType, b: ColumnType) -> ColumnType {
    use ColumnType::*;
    match (a, b) {
        (Empty, x) | (x, Empty) => x,
        (x, y) if x == y => x,
        (Integer, Float) | (Float, Integer) => Float,
        _ => Text,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn null_detection() {
        for raw in ["", "  ", "NA", "n/a", "NULL", "-"] {
            assert!(matches!(InferredValue::parse(raw), InferredValue::Null), "{raw}");
        }
    }

    #[test]
    fn integer_vs_float() {
        assert!(matches!(InferredValue::parse("42"),  InferredValue::Int(42)));
        assert!(matches!(InferredValue::parse("3.14"), InferredValue::Float(_)));
    }

    #[test]
    fn boolean_keywords() {
        assert!(matches!(InferredValue::parse("yes"),  InferredValue::Bool(true)));
        assert!(matches!(InferredValue::parse("FALSE"), InferredValue::Bool(false)));
    }

    #[test]
    fn date_iso_only() {
        assert!(matches!(InferredValue::parse("2024-01-15"), InferredValue::Date(_)));
        assert!(matches!(InferredValue::parse("2024/01/15"), InferredValue::Text(_)));
    }

    #[test]
    fn unification_rules() {
        use ColumnType::*;
        assert_eq!(unify(Empty, Integer), Integer);
        assert_eq!(unify(Integer, Float), Float);
        assert_eq!(unify(Integer, Text),  Text);
        assert_eq!(unify(Date, Integer),  Text);
        assert_eq!(unify(Boolean, Boolean), Boolean);
    }
}
