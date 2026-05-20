//! Type inference engine for CSV columns.
//!
//! Detects the most likely type of a column by sampling values and
//! attempting to parse them in order: Boolean → Integer → Float → Date → Categorical/Text.

/// The inferred data type for a column.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum InferredType {
    /// Boolean values (true/false, yes/no, 0/1)
    Boolean,
    /// Integer values (i64)
    Integer,
    /// Floating point values (f64)
    Float,
    /// Date values (common formats)
    Date,
    /// Categorical/discrete values (< max_unique)
    Categorical,
    /// Free text (> max_unique or non-parseable)
    Text,
}

impl std::fmt::Display for InferredType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            InferredType::Boolean => write!(f, "Boolean"),
            InferredType::Integer => write!(f, "Integer"),
            InferredType::Float => write!(f, "Float"),
            InferredType::Date => write!(f, "Date"),
            InferredType::Categorical => write!(f, "Categorical"),
            InferredType::Text => write!(f, "Text"),
        }
    }
}

/// Type inference engine that samples column values.
pub struct TypeInferrer {
    max_unique: usize,
}

impl TypeInferrer {
    /// Create a new type inferrer.
    ///
    /// # Arguments
    /// * `max_unique` - Threshold above which a column is considered Text instead of Categorical
    pub fn new(max_unique: usize, _sample_size: usize) -> Self {
        Self {
            max_unique,
        }
    }

    /// Infer the type from a sample of values.
    pub fn infer(&self, values: &[&str]) -> InferredType {
        if values.is_empty() {
            return InferredType::Text;
        }

        // Try Boolean
        if self.try_boolean(values) {
            return InferredType::Boolean;
        }

        // Try Integer
        if self.try_integer(values) {
            return InferredType::Integer;
        }

        // Try Float
        if self.try_float(values) {
            return InferredType::Float;
        }

        // Try Date
        if self.try_date(values) {
            return InferredType::Date;
        }

        // Decide between Categorical and Text
        let unique_count = values.iter().collect::<std::collections::HashSet<_>>().len();
        if unique_count <= self.max_unique {
            InferredType::Categorical
        } else {
            InferredType::Text
        }
    }

    fn try_boolean(&self, values: &[&str]) -> bool {
        values.iter().all(|v| {
            let lower = v.to_lowercase();
            matches!(
                lower.as_str(),
                "true" | "false" | "yes" | "no" | "y" | "n" | "0" | "1"
            )
        })
    }

    fn try_integer(&self, values: &[&str]) -> bool {
        values.iter().all(|v| v.parse::<i64>().is_ok())
    }

    fn try_float(&self, values: &[&str]) -> bool {
        values.iter().all(|v| v.parse::<f64>().is_ok())
    }

    fn try_date(&self, values: &[&str]) -> bool {
        let formats = ["%Y-%m-%d", "%m/%d/%Y", "%d-%b-%Y", "%Y/%m/%d"];
        values.iter().all(|v| {
            formats
                .iter()
                .any(|fmt| chrono::NaiveDate::parse_from_str(v, fmt).is_ok())
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_infer_boolean() {
        let inferrer = TypeInferrer::new(50, 100);
        let vals = vec!["true", "false", "true"];
        assert_eq!(inferrer.infer(&vals), InferredType::Boolean);
    }

    #[test]
    fn test_infer_integer() {
        let inferrer = TypeInferrer::new(50, 100);
        let vals = vec!["42", "100", "-5"];
        assert_eq!(inferrer.infer(&vals), InferredType::Integer);
    }

    #[test]
    fn test_infer_float() {
        let inferrer = TypeInferrer::new(50, 100);
        let vals = vec!["3.14", "2.71", "-1.5"];
        assert_eq!(inferrer.infer(&vals), InferredType::Float);
    }

    #[test]
    fn test_infer_date() {
        let inferrer = TypeInferrer::new(50, 100);
        let vals = vec!["2024-01-15", "2024-02-20", "2024-03-10"];
        assert_eq!(inferrer.infer(&vals), InferredType::Date);
    }

    #[test]
    fn test_infer_categorical() {
        let inferrer = TypeInferrer::new(50, 100);
        let vals = vec!["cat", "dog", "bird"];
        assert_eq!(inferrer.infer(&vals), InferredType::Categorical);
    }
}
