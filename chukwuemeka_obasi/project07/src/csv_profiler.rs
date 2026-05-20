use std::error::Error;

use csv::{Reader, StringRecord};

use crate::profiler::{ColumnProfiler, ProfilerFactory};
use crate::utils::infer_type;

pub struct ColumnSummary {
    pub header: String,
    pub report: String,
}

pub struct CsvProfiler<F> {
    factory: F,
    sample_size: usize,
}

impl<F> CsvProfiler<F>
where
    F: ProfilerFactory,
{
    pub fn new(factory: F) -> Self {
        Self {
            factory,
            sample_size: 100,
        }
    }

    pub fn analyze_file(&self, path: &str) -> Result<Vec<ColumnSummary>, Box<dyn Error>> {
        let mut reader = Reader::from_path(path)?;
        let headers = reader.headers()?.clone();
        let samples = self.collect_samples(&mut reader, headers.len())?;
        let mut profilers = self.build_profilers(&samples);

        let mut reader = Reader::from_path(path)?;
        for result in reader.records() {
            let record = result?;
            Self::update_profilers(&record, &mut profilers);
        }

        Ok(headers
            .iter()
            .zip(profilers.iter_mut())
            .map(|(header, profiler)| {
                profiler.finalize();
                ColumnSummary {
                    header: header.to_string(),
                    report: profiler.report(),
                }
            })
            .collect())
    }

    fn collect_samples(
        &self,
        reader: &mut Reader<std::fs::File>,
        column_count: usize,
    ) -> Result<Vec<Vec<String>>, csv::Error> {
        let mut samples: Vec<Vec<String>> = vec![Vec::new(); column_count];

        for result in reader.records().take(self.sample_size) {
            let record = result?;
            for (index, field) in record.iter().enumerate() {
                samples[index].push(field.to_string());
            }
        }

        Ok(samples)
    }

    fn build_profilers(&self, samples: &[Vec<String>]) -> Vec<Box<dyn ColumnProfiler>> {
        samples
            .iter()
            .map(|column| self.factory.create(&infer_type(column)))
            .collect()
    }

    fn update_profilers(record: &StringRecord, profilers: &mut [Box<dyn ColumnProfiler>]) {
        for (index, field) in record.iter().enumerate() {
            if let Some(profiler) = profilers.get_mut(index) {
                profiler.update(field);
            }
        }
    }
}
