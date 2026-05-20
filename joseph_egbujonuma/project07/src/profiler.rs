use crate::types::DataType;
use csv::StringRecord;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct ColumnProfile {
    pub name: String,
    pub inferred_type: DataType,
    pub row_count: usize,
    pub null_count: usize,
    pub unique_count: usize,
    pub min: Option<f64>,
    pub max: Option<f64>,
    pub mean: Option<f64>,
    pub shortest_len: Option<usize>,
    pub longest_len: Option<usize>,
    pub mixed_type_warning: bool,
    pub constant_warning: bool,

    values: Vec<f64>,
    freq: HashMap<String, usize>,
}

impl ColumnProfile {
    pub fn new(name: String) -> Self {
        Self {
            name,
            inferred_type: DataType::Integer,
            row_count: 0,
            null_count: 0,
            unique_count: 0,
            min: None,
            max: None,
            mean: None,
            shortest_len: None,
            longest_len: None,
            mixed_type_warning: false,
            constant_warning: false,
            values: Vec::new(),
            freq: HashMap::new(),
        }
    }

    pub fn update(&mut self, value: &str) {
        self.row_count += 1;

        let trimmed = value.trim();

        if trimmed.is_empty() {
            self.null_count += 1;
            return;
        }

        let observed_type = infer_value_type(trimmed);

        if !type_compatible(&self.inferred_type, &observed_type) {
            self.mixed_type_warning = true;
            self.inferred_type = promote_type(&self.inferred_type, &observed_type);
        } else {
            self.inferred_type = promote_type(&self.inferred_type, &observed_type);
        }

        match observed_type {
            DataType::Integer | DataType::Float => {
                if let Ok(v) = trimmed.parse::<f64>() {
                    self.values.push(v);
                    self.min = Some(self.min.map_or(v, |m| m.min(v)));
                    self.max = Some(self.max.map_or(v, |m| m.max(v)));
                }
            }
            DataType::Text | DataType::Boolean => {
                let len = trimmed.len();
                self.shortest_len = Some(self.shortest_len.map_or(len, |m| m.min(len)));
                self.longest_len = Some(self.longest_len.map_or(len, |m| m.max(len)));
            }
        }

        *self.freq.entry(trimmed.to_string()).or_insert(0) += 1;
    }

    pub fn finalize(&mut self) {
        self.unique_count = self.freq.len();

        if !self.values.is_empty() {
            let sum: f64 = self.values.iter().sum();
            self.mean = Some(sum / self.values.len() as f64);
        }

        if self.unique_count == 1 && self.row_count > 0 {
            self.constant_warning = true;
        }
    }

    pub fn top_values(&self, n: usize) -> Vec<(&String, &usize)> {
        let mut items: Vec<(&String, &usize)> = self.freq.iter().collect();
        items.sort_by(|a, b| b.1.cmp(a.1).then_with(|| a.0.cmp(b.0)));
        items.into_iter().take(n).collect()
    }
}

#[derive(Debug)]
pub struct CsvProfiler {
    pub columns: Vec<ColumnProfile>,
}

impl CsvProfiler {
    pub fn new(headers: Option<StringRecord>) -> Self {
        let columns = headers
            .map(|h| {
                h.iter()
                    .map(|name| ColumnProfile::new(name.to_string()))
                    .collect()
            })
            .unwrap_or_default();

        Self { columns }
    }

    pub fn process_record(&mut self, record: &StringRecord) {
        if self.columns.is_empty() {
            self.columns = (0..record.len())
                .map(|i| ColumnProfile::new(format!("column_{i}")))
                .collect();
        }

        for (i, value) in record.iter().enumerate() {
            if let Some(col) = self.columns.get_mut(i) {
                col.update(value);
            }
        }
    }

    pub fn finalize(&mut self) {
        for col in &mut self.columns {
            col.finalize();
        }
    }
}

fn infer_value_type(value: &str) -> DataType {
    if value.parse::<i64>().is_ok() {
        DataType::Integer
    } else if value.parse::<f64>().is_ok() {
        DataType::Float
    } else if value.eq_ignore_ascii_case("true") || value.eq_ignore_ascii_case("false") {
        DataType::Boolean
    } else {
        DataType::Text
    }
}

fn type_compatible(current: &DataType, observed: &DataType) -> bool {
    matches!(
        (current, observed),
        (DataType::Integer, DataType::Integer)
            | (DataType::Integer, DataType::Float)
            | (DataType::Float, DataType::Integer)
            | (DataType::Float, DataType::Float)
            | (DataType::Boolean, DataType::Boolean)
            | (DataType::Text, _)
            | (_, DataType::Text)
    )
}

fn promote_type(current: &DataType, observed: &DataType) -> DataType {
    match (current, observed) {
        (DataType::Text, _) | (_, DataType::Text) => DataType::Text,
        (DataType::Float, _) | (_, DataType::Float) => DataType::Float,
        (DataType::Boolean, DataType::Boolean) => DataType::Boolean,
        (DataType::Integer, DataType::Integer) => DataType::Integer,
        _ => DataType::Text,
    }
}