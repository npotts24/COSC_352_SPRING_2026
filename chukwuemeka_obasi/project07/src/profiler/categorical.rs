use std::collections::HashMap;
use super::traits::{ReportRenderer, ValueProfiler};

pub struct CategoricalProfiler {
    counts: HashMap<String, usize>,
    nulls: usize,
}

impl CategoricalProfiler {
    pub fn new() -> Self {
        Self {
            counts: HashMap::new(),
            nulls: 0,
        }
    }
}

impl ValueProfiler for CategoricalProfiler {
    fn update(&mut self, value: &str) {
        if value.trim().is_empty() {
            self.nulls += 1;
            return;
        }

        *self.counts.entry(value.to_string()).or_insert(0) += 1;
    }

    fn finalize(&mut self) {}
}

impl ReportRenderer for CategoricalProfiler {
    fn report(&self) -> String {
        let mut pairs: Vec<_> = self.counts.iter().collect();
        pairs.sort_by(|a, b| b.1.cmp(a.1));

        let top: Vec<String> = pairs
            .iter()
            .take(5)
            .map(|(v, c)| format!("{} ({})", v, c))
            .collect();

        format!(
            "Type: Categorical/Text
Unique Values: {}
Nulls: {}
Top Values:
{}",
            self.counts.len(),
            self.nulls,
            top.join("\n")
        )
    }
}
