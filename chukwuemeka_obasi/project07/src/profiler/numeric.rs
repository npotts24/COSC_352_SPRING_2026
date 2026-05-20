use super::traits::{ReportRenderer, ValueProfiler};

pub struct NumericProfiler {
    count: usize,
    nulls: usize,
    mean: f64,
    m2: f64,
    min: f64,
    max: f64,
}

impl NumericProfiler {
    pub fn new() -> Self {
        Self {
            count: 0,
            nulls: 0,
            mean: 0.0,
            m2: 0.0,
            min: f64::MAX,
            max: f64::MIN,
        }
    }
}

impl ValueProfiler for NumericProfiler {
    fn update(&mut self, value: &str) {
        if value.trim().is_empty() {
            self.nulls += 1;
            return;
        }

        if let Ok(v) = value.parse::<f64>() {
            self.count += 1;

            let delta = v - self.mean;
            self.mean += delta / self.count as f64;
            let delta2 = v - self.mean;
            self.m2 += delta * delta2;

            if v < self.min {
                self.min = v;
            }
            if v > self.max {
                self.max = v;
            }
        }
    }

    fn finalize(&mut self) {}
}

impl ReportRenderer for NumericProfiler {
    fn report(&self) -> String {
        let variance = if self.count > 1 {
            self.m2 / (self.count as f64 - 1.0)
        } else {
            0.0
        };

        format!(
            "Type: Numeric
Count: {}
Nulls: {}
Mean: {:.2}
Std Dev: {:.2}
Min: {:.2}
Max: {:.2}",
            self.count,
            self.nulls,
            self.mean,
            variance.sqrt(),
            self.min,
            self.max
        )
    }
}
