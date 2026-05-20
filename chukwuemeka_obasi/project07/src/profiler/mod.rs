pub mod traits;
pub mod numeric;
pub mod categorical;

use crate::utils::DataType;
use numeric::NumericProfiler;
use categorical::CategoricalProfiler;
pub use traits::ColumnProfiler;

pub trait ProfilerFactory {
    fn create(&self, dtype: &DataType) -> Box<dyn ColumnProfiler>;
}

pub struct TypeBasedProfilerFactory;

impl ProfilerFactory for TypeBasedProfilerFactory {
    fn create(&self, dtype: &DataType) -> Box<dyn ColumnProfiler> {
        match dtype {
            DataType::Integer | DataType::Float => Box::new(NumericProfiler::new()),
            DataType::Text => Box::new(CategoricalProfiler::new()),
        }
    }
}
