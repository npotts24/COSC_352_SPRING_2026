/// Column data-type inference from string cell values.
///
/// Uses a voting / priority scheme: attempt to parse each non-empty cell as
/// integer → float → boolean → date → text, then pick the dominant type.
use crate::types::InferredType;
use chrono::NaiveDate;

/// Formats tried when parsing date strings.
const DATE_FORMATS: &[&str] = &[
    "%Y-%m-%d",
    "%m/%d/%Y",
    "%m-%d-%Y",
    "%d/%m/%Y",
    "%Y/%m/%d",
    "%b %d, %Y",
    "%B %d, %Y",
    "%d %b %Y",
    "%d %B %Y",
];

/// Try to parse a single cell value and return the narrowest matching type.
pub fn infer_cell_type(value: &str) -> InferredType {
    let trimmed = value.trim();

    if trimmed.is_empty() {
        // Null / missing — doesn't vote.
        return InferredType::Text;
    }

    // Integer check
    if trimmed.parse::<i64>().is_ok() {
        return InferredType::Integer;
    }

    // Float check
    if trimmed.parse::<f64>().is_ok() {
        return InferredType::Float;
    }

    // Boolean check
    let lower = trimmed.to_lowercase();
    if matches!(lower.as_str(), "true" | "false" | "yes" | "no" | "0" | "1") {
        return InferredType::Boolean;
    }

    // Date check
    if try_parse_date(trimmed).is_some() {
        return InferredType::Date;
    }

    InferredType::Text
}

/// Attempt to parse a date string using common formats.
pub fn try_parse_date(value: &str) -> Option<NaiveDate> {
    let trimmed = value.trim();
    for fmt in DATE_FORMATS {
        if let Ok(d) = NaiveDate::parse_from_str(trimmed, fmt) {
            return Some(d);
        }
    }
    None
}

/// Tracks type votes across sampled rows for a single column, then resolves
/// the dominant inferred type.
#[derive(Debug, Default)]
pub struct TypeVoter {
    pub integer: usize,
    pub float: usize,
    pub boolean: usize,
    pub date: usize,
    pub text: usize,
    pub empty: usize,
    pub total: usize,
}

impl TypeVoter {
    pub fn vote(&mut self, value: &str) {
        self.total += 1;
        let trimmed = value.trim();
        if trimmed.is_empty() {
            self.empty += 1;
            return;
        }
        match infer_cell_type(trimmed) {
            InferredType::Integer => self.integer += 1,
            InferredType::Float => self.float += 1,
            InferredType::Boolean => self.boolean += 1,
            InferredType::Date => self.date += 1,
            InferredType::Text | InferredType::Categorical => self.text += 1,
        }
    }

    /// Returns the dominant type and whether mixed types were detected.
    pub fn resolve(&self) -> (InferredType, bool) {
        let non_empty = self.total - self.empty;
        if non_empty == 0 {
            return (InferredType::Text, false);
        }

        // Find the type with the most votes.
        let counts = [
            (InferredType::Integer, self.integer),
            (InferredType::Float, self.float),
            (InferredType::Boolean, self.boolean),
            (InferredType::Date, self.date),
            (InferredType::Text, self.text),
        ];

        let (dominant_type, dominant_count) = counts
            .iter()
            .max_by_key(|(_, c)| *c)
            .copied()
            .unwrap();

        // Integer + float mix → promote to float.
        if dominant_type == InferredType::Integer && self.float > 0 {
            let numeric_total = self.integer + self.float;
            let non_numeric = non_empty - numeric_total;
            let mixed = non_numeric > 0;
            return (InferredType::Float, mixed);
        }

        let mixed = dominant_count < non_empty;
        (dominant_type, mixed)
    }
}
