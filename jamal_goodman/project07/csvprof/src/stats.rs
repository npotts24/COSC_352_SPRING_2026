use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct ColumnStats {
    pub count: usize,
    pub nulls: usize,
    pub values: Vec<String>,
    pub frequencies: HashMap<String, usize>,
}

impl ColumnStats {
    pub fn new() -> Self {
        Self {
            count: 0,
            nulls: 0,
            values: Vec::new(),
            frequencies: HashMap::new(),
        }
    }

    pub fn add(&mut self, val: &str) {
        self.count += 1;

        if val.trim().is_empty() {
            self.nulls += 1;
        } else {
            self.values.push(val.to_string());
            *self.frequencies.entry(val.to_string()).or_insert(0) += 1;
        }
    }

    pub fn unique_count(&self) -> usize {
        self.frequencies.len()
    }

    pub fn mean(&self) -> Option<f64> {
        let nums: Vec<f64> = self.values.iter().filter_map(|v| v.parse::<f64>().ok()).collect();
        if nums.is_empty() {
            return None;
        }
        Some(nums.iter().sum::<f64>() / nums.len() as f64)
    }

    pub fn min(&self) -> Option<f64> {
        self.values
            .iter()
            .filter_map(|v| v.parse::<f64>().ok())
            .reduce(f64::min)
    }

    pub fn max(&self) -> Option<f64> {
        self.values
            .iter()
            .filter_map(|v| v.parse::<f64>().ok())
            .reduce(f64::max)
    }
}