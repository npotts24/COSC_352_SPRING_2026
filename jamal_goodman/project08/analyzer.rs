pub trait ColumnAnalyzer {
    fn process(&mut self, value: &str);
    fn report(&self) -> String;
}
pub struct BasicAnalyzer {
    pub count: usize,
    pub missing: usize,
}

impl BasicAnalyzer {
    pub fn new() -> Self {
        Self { count: 0, missing: 0 }
    }
}

impl ColumnAnalyzer for BasicAnalyzer {
    fn process(&mut self, value: &str) {
        self.count += 1;
        if value.trim().is_empty() {
            self.missing += 1;
        }
    }

    fn report(&self) -> String {
        format!("Count: {}, Missing: {}", self.count, self.missing)
    }
}