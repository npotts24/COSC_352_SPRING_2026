use crate::cli::Args;
use crate::column::ColumnProfile;
use crate::error::{CsvProfError, Result};
use crate::stats;
use crate::types::{infer_type, parse_bool_like, parse_date_like, is_null_like, InferredType};
use csv::{Reader, StringRecord};
use std::collections::HashSet;
use std::io;
use std::path::Path;

pub struct Profiler;

pub trait Compute {
    fn compute(values: &[String], args: &Args) -> ColumnProfile;
}

pub struct IntegerComputer;
pub struct FloatComputer;
pub struct BooleanComputer;
pub struct DateComputer;
pub struct CategoricalComputer;
pub struct TextComputer;

impl Profiler {
    pub fn profile(file: &str, args: &Args) -> Result<Vec<ColumnProfile>> {
        if file == "-" {
            let reader = csv::Reader::from_reader(io::stdin());
            return Self::profile_from_reader(reader, args);
        }

        if !Path::new(file).exists() {
            return Err(CsvProfError::InvalidFile(file.to_string()));
        }

        let reader = csv::Reader::from_path(file)?;
        Self::profile_from_reader(reader, args)
    }

    pub fn profile_from_reader<R: io::Read>(mut reader: Reader<R>, args: &Args) -> Result<Vec<ColumnProfile>> {
        let headers = reader
            .headers()?
            .iter()
            .map(ToOwned::to_owned)
            .collect::<Vec<String>>();

        let mut columns = vec![Vec::<String>::new(); headers.len()];

        for (idx, result) in reader.records().enumerate() {
            if args.sample_rows.is_some_and(|limit| idx >= limit) {
                break;
            }

            let record = result?;
            Self::push_record(&mut columns, &record);
        }

        let profiles = headers
            .iter()
            .enumerate()
            .map(|(index, name)| {
                let values = &columns[index];
                let inferred = infer_type(values);
                let mut profile = match inferred {
                    InferredType::Integer => IntegerComputer::compute(values, args),
                    InferredType::Float => FloatComputer::compute(values, args),
                    InferredType::Boolean => BooleanComputer::compute(values, args),
                    InferredType::Date => DateComputer::compute(values, args),
                    InferredType::Categorical => CategoricalComputer::compute(values, args),
                    InferredType::Text => TextComputer::compute(values, args),
                };

                profile.name = name.clone();
                profile.inferred_type = inferred;
                profile.unique_count = non_null_unique_count(values);
                profile.is_constant = profile.unique_count == 1;
                profile.has_mixed_types = has_mixed_types(values);
                profile
            })
            .collect();

        Ok(profiles)
    }

    pub fn push_record(columns: &mut [Vec<String>], record: &StringRecord) {
        columns.iter_mut().enumerate().for_each(|(idx, col)| {
            col.push(record.get(idx).unwrap_or_default().to_string());
        });
    }
}

impl Compute for IntegerComputer {
    fn compute(values: &[String], args: &Args) -> ColumnProfile {
        numeric_profile(values, args, true)
    }
}

impl Compute for FloatComputer {
    fn compute(values: &[String], args: &Args) -> ColumnProfile {
        numeric_profile(values, args, false)
    }
}

impl Compute for BooleanComputer {
    fn compute(values: &[String], args: &Args) -> ColumnProfile {
        frequency_profile(values, args, InferredType::Boolean)
    }
}

impl Compute for DateComputer {
    fn compute(values: &[String], _args: &Args) -> ColumnProfile {
        let row_count = values.len();
        let null_count = values.iter().filter(|v| is_null_like(v)).count();
        let parsed = values
            .iter()
            .filter_map(|v| (!is_null_like(v)).then_some(v))
            .filter_map(|v| parse_date_like(v))
            .collect::<Vec<_>>();

        let min = parsed.iter().min().map(|d| d.format("%Y-%m-%d").to_string());
        let max = parsed.iter().max().map(|d| d.format("%Y-%m-%d").to_string());

        let mut profile = ColumnProfile::empty(InferredType::Date, row_count, null_count);
        profile.min = min;
        profile.max = max;
        profile
    }
}

impl Compute for CategoricalComputer {
    fn compute(values: &[String], args: &Args) -> ColumnProfile {
        frequency_profile(values, args, InferredType::Categorical)
    }
}

impl Compute for TextComputer {
    fn compute(values: &[String], _args: &Args) -> ColumnProfile {
        let row_count = values.len();
        let null_count = values.iter().filter(|v| is_null_like(v)).count();

        let lengths: Vec<usize> = values
            .iter()
            .map(|v| v.trim())
            .filter(|v| !is_null_like(v))
            .map(str::len)
            .collect();

        let mut profile = ColumnProfile::empty(InferredType::Text, row_count, null_count);
        profile.shortest_len = lengths.iter().min().copied();
        profile.longest_len = lengths.iter().max().copied();
        profile
    }
}

pub fn non_null_unique_count(values: &[String]) -> usize {
    values
        .iter()
        .map(|v| v.trim())
        .filter(|v| !is_null_like(v))
        .collect::<HashSet<&str>>()
        .len()
}

pub fn has_mixed_types(values: &[String]) -> bool {
    #[derive(Debug, Clone, Copy, Hash, Eq, PartialEq)]
    enum Kind {
        Integer,
        Float,
        Boolean,
        Date,
        Text,
    }

    let kinds = values
        .iter()
        .map(|v| v.trim())
        .filter(|v| !is_null_like(v))
        .map(|v| {
            if v.parse::<i64>().is_ok() {
                Kind::Integer
            } else if v.parse::<f64>().is_ok() {
                Kind::Float
            } else if parse_bool_like(v).is_some() {
                Kind::Boolean
            } else if parse_date_like(v).is_some() {
                Kind::Date
            } else {
                Kind::Text
            }
        })
        .collect::<HashSet<Kind>>();

    kinds.len() > 1
}

pub fn numeric_profile(values: &[String], args: &Args, as_integer: bool) -> ColumnProfile {
    let row_count = values.len();
    let null_count = values.iter().filter(|v| is_null_like(v)).count();

    let non_null: Vec<&str> = values
        .iter()
        .map(String::as_str)
        .map(str::trim)
        .filter(|v| !is_null_like(v))
        .collect();

    let numbers: Vec<f64> = non_null
        .iter()
        .filter_map(|v| {
            if as_integer {
                v.parse::<i64>().ok().map(|n| n as f64)
            } else {
                v.parse::<f64>().ok()
            }
        })
        .collect();

    let mut profile = ColumnProfile::empty(
        if as_integer {
            InferredType::Integer
        } else {
            InferredType::Float
        },
        row_count,
        null_count,
    );

    if numbers.is_empty() {
        return profile;
    }

    let mut sorted = numbers.clone();
    sorted.sort_by_key(|v| ordered_float::OrderedFloat(*v));

    profile.min = sorted.first().map(|v| format_number(*v, as_integer));
    profile.max = sorted.last().map(|v| format_number(*v, as_integer));
    profile.mean = stats::mean(&numbers);

    let mut for_median = numbers.clone();
    profile.median = stats::median(&mut for_median);
    profile.std_dev = stats::std_dev(&numbers);

    if args.percentiles {
        profile.p5 = stats::percentile(&sorted, 5.0);
        profile.p25 = stats::percentile(&sorted, 25.0);
        profile.p75 = stats::percentile(&sorted, 75.0);
        profile.p95 = stats::percentile(&sorted, 95.0);
    }

    profile
}

pub fn frequency_profile(values: &[String], args: &Args, inferred: InferredType) -> ColumnProfile {
    let row_count = values.len();
    let null_count = values.iter().filter(|v| is_null_like(v)).count();

    let non_null = values
        .iter()
        .map(|v| v.trim().to_string())
        .filter(|v| !is_null_like(v))
        .collect::<Vec<String>>();

    let freq = stats::frequency_map(&non_null);

    let mut profile = ColumnProfile::empty(inferred, row_count, null_count);
    profile.top5_most_frequent = stats::top_n(&freq, 5, false);
    profile.top5_least_frequent = stats::top_n(&freq, 5, true);
    if args.histogram {
        profile.histogram = stats::top_n(&freq, freq.len(), false);
    }

    profile
}

pub fn format_number(value: f64, as_integer: bool) -> String {
    if as_integer {
        format!("{}", value as i64)
    } else {
        format!("{value:.6}").trim_end_matches('0').trim_end_matches('.').to_string()
    }
}
