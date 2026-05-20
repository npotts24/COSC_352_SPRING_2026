use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone)]
pub enum DataType {
    Integer,
    Float,
    Boolean,
    Text,
    Mixed,
}

pub struct ColumnProfile {
    pub name: String,
    pub dtype: DataType,
    pub row_count: usize,
    pub null_count: usize,
    pub unique: HashSet<String>,
    pub freq: HashMap<String, usize>,
    pub values: Vec<f64>,
}