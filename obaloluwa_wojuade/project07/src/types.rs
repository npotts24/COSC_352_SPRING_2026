use chrono::NaiveDate;
use serde::Serialize;
use std::collections::HashSet;
use std::fmt;

#[derive(Debug, Clone, Serialize)]
pub enum InferredType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

impl fmt::Display for InferredType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Self::Integer => "Integer",
            Self::Float => "Float",
            Self::Boolean => "Boolean",
            Self::Date => "Date",
            Self::Categorical => "Categorical",
            Self::Text => "Text",
        };
        write!(f, "{s}")
    }
}

pub fn is_null_like(value: &str) -> bool {
    matches!(value.trim(), "" | "null" | "NULL" | "N/A" | "n/a" | "NA")
}

pub fn parse_bool_like(value: &str) -> Option<bool> {
    match value.trim().to_ascii_lowercase().as_str() {
        "true" | "yes" | "1" => Some(true),
        "false" | "no" | "0" => Some(false),
        _ => None,
    }
}

pub fn parse_date_like(value: &str) -> Option<NaiveDate> {
    const FORMATS: [&str; 3] = ["%Y-%m-%d", "%m/%d/%Y", "%d-%m-%Y"];
    FORMATS
        .iter()
        .find_map(|fmt| NaiveDate::parse_from_str(value.trim(), fmt).ok())
}

pub fn infer_type(values: &[String]) -> InferredType {
    let non_null: Vec<&str> = values
        .iter()
        .map(String::as_str)
        .map(str::trim)
        .filter(|v| !is_null_like(v))
        .collect();

    if non_null.is_empty() {
        return InferredType::Text;
    }

    let is_integer = non_null.iter().all(|v| v.parse::<i64>().is_ok());
    if is_integer {
        return InferredType::Integer;
    }

    let is_float = non_null.iter().all(|v| v.parse::<f64>().is_ok());
    if is_float {
        return InferredType::Float;
    }

    let is_bool = non_null.iter().all(|v| parse_bool_like(v).is_some());
    if is_bool {
        return InferredType::Boolean;
    }

    let is_date = non_null.iter().all(|v| parse_date_like(v).is_some());
    if is_date {
        return InferredType::Date;
    }

    let unique_count = non_null.iter().copied().collect::<HashSet<&str>>().len();
    if unique_count <= 20 && non_null.len() > 10 {
        return InferredType::Categorical;
    }

    InferredType::Text
}
