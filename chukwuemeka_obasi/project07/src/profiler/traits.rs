pub trait ValueProfiler {
    fn update(&mut self, value: &str);
    fn finalize(&mut self);
}

pub trait ReportRenderer {
    fn report(&self) -> String;
}

pub trait ColumnProfiler: ValueProfiler + ReportRenderer {}

impl<T> ColumnProfiler for T where T: ValueProfiler + ReportRenderer {}
