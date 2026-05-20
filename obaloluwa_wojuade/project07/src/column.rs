use crate::types::InferredType;
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct ColumnProfile {
    pub name: String,
    pub inferred_type: InferredType,
    pub row_count: usize,
    pub null_count: usize,
    pub unique_count: usize,
    pub min: Option<String>,
    pub max: Option<String>,
    pub mean: Option<f64>,
    pub median: Option<f64>,
    pub std_dev: Option<f64>,
    pub p5: Option<f64>,
    pub p25: Option<f64>,
    pub p75: Option<f64>,
    pub p95: Option<f64>,
    pub top5_most_frequent: Vec<(String, usize)>,
    pub top5_least_frequent: Vec<(String, usize)>,
    pub shortest_len: Option<usize>,
    pub longest_len: Option<usize>,
    pub is_constant: bool,
    pub has_mixed_types: bool,
    pub histogram: Vec<(String, usize)>,
}

impl ColumnProfile {
    pub fn empty(inferred_type: InferredType, row_count: usize, null_count: usize) -> Self {
        Self {
            name: String::new(),
            inferred_type,
            row_count,
            null_count,
            unique_count: 0,
            min: None,
            max: None,
            mean: None,
            median: None,
            std_dev: None,
            p5: None,
            p25: None,
            p75: None,
            p95: None,
            top5_most_frequent: Vec::new(),
            top5_least_frequent: Vec::new(),
            shortest_len: None,
            longest_len: None,
            is_constant: false,
            has_mixed_types: false,
            histogram: Vec::new(),
        }
    }
}
