use crate::{
    profile::{
        BooleanStats, CategoricalStats, ColumnProfile, DateStats, NumericStats, Profiler,
        ProfilerOptions, TextStats, TypeStats, Warning,
    },
    stats::{find_outlier_count, frequencies, mean, median, percentile, std_dev},
    types::{is_boolean, is_date, is_float, is_integer, is_null, ColumnType},
};

// ── Helper ────────────────────────────────────────────────────────────────────

fn base_warnings(values: &[String], unique_count: usize, null_pct: f64) -> Vec<Warning> {
    let mut warnings = Vec::new();

    if null_pct >= 50.0 {
        warnings.push(Warning::HighNullRate { null_pct });
    }

    let non_null_count = values.iter().filter(|v| !is_null(v)).count();
    if non_null_count > 0 && unique_count == 1 {
        warnings.push(Warning::ConstantColumn);
    }

    warnings
}

fn detect_mixed_types(values: &[String]) -> Option<Warning> {
    let non_null: Vec<&str> = values
        .iter()
        .filter(|v| !is_null(v))
        .map(|v| v.as_str())
        .collect();

    let mut seen: std::collections::HashSet<&str> = std::collections::HashSet::new();
    for v in &non_null {
        if is_boolean(v) {
            seen.insert("boolean");
        } else if is_integer(v) {
            seen.insert("integer");
        } else if is_float(v) {
            seen.insert("float");
        } else if is_date(v) {
            seen.insert("date");
        } else {
            seen.insert("text");
        }
    }

    if seen.len() > 1 {
        let mut types: Vec<String> = seen.iter().map(|s| s.to_string()).collect();
        types.sort();
        Some(Warning::MixedTypes { types_seen: types })
    } else {
        None
    }
}

// ── Default (universal) profiler ──────────────────────────────────────────────

/// Dispatches to the correct typed profiler based on `inferred_type`.
pub struct DispatchProfiler;

impl Profiler for DispatchProfiler {
    fn profile(
        &self,
        name: &str,
        values: &[String],
        inferred_type: ColumnType,
        opts: &ProfilerOptions,
    ) -> ColumnProfile {
        let row_count = values.len();
        let null_count = values.iter().filter(|v| is_null(v)).count();
        let null_pct = if row_count == 0 {
            0.0
        } else {
            null_count as f64 / row_count as f64 * 100.0
        };

        let non_null: Vec<&String> = values.iter().filter(|v| !is_null(v)).collect();
        let unique_count = non_null
            .iter()
            .collect::<std::collections::HashSet<_>>()
            .len();

        let mut warnings = base_warnings(values, unique_count, null_pct);
        if let Some(w) = detect_mixed_types(values) {
            warnings.push(w);
        }

        let type_stats = match &inferred_type {
            ColumnType::Integer | ColumnType::Float => {
                Some(numeric_stats(values, opts, &mut warnings))
            }
            ColumnType::Date => Some(date_stats(values)),
            ColumnType::Categorical => Some(categorical_stats(
                values,
                unique_count,
                opts,
                &mut warnings,
            )),
            ColumnType::Boolean => Some(boolean_stats(values)),
            ColumnType::Text => Some(text_stats(values)),
        };

        ColumnProfile {
            name: name.to_string(),
            inferred_type,
            row_count,
            null_count,
            null_pct,
            unique_count,
            type_stats,
            warnings,
        }
    }
}

// ── Typed stat builders ───────────────────────────────────────────────────────

fn numeric_stats(values: &[String], opts: &ProfilerOptions, _warnings: &mut Vec<Warning>) -> TypeStats {
    let mut nums: Vec<f64> = values
        .iter()
        .filter(|v| !is_null(v))
        .filter_map(|v| v.trim().parse::<f64>().ok())
        .collect();
    nums.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let outlier_count = find_outlier_count(&nums);

    let (p5, p25, p75, p95) = if opts.percentiles {
        (
            percentile(&nums, 5.0),
            percentile(&nums, 25.0),
            percentile(&nums, 75.0),
            percentile(&nums, 95.0),
        )
    } else {
        (None, None, None, None)
    };

    if outlier_count > 0 {
        // Not a formal warning but we surface it in the stats struct
    }

    TypeStats::Numeric(NumericStats {
        min: nums.first().copied().unwrap_or(0.0),
        max: nums.last().copied().unwrap_or(0.0),
        mean: mean(&nums).unwrap_or(0.0),
        median: median(&nums).unwrap_or(0.0),
        std_dev: std_dev(&nums).unwrap_or(0.0),
        p5,
        p25,
        p75,
        p95,
        outlier_count,
    })
}

fn date_stats(values: &[String]) -> TypeStats {
    let mut dates: Vec<&str> = values
        .iter()
        .filter(|v| !is_null(v))
        .map(|v| v.as_str())
        .collect();
    dates.sort();

    TypeStats::Date(DateStats {
        min: dates.first().map(|s| s.to_string()).unwrap_or_default(),
        max: dates.last().map(|s| s.to_string()).unwrap_or_default(),
    })
}

fn categorical_stats(
    values: &[String],
    unique_count: usize,
    opts: &ProfilerOptions,
    warnings: &mut Vec<Warning>,
) -> TypeStats {
    let non_null: Vec<String> = values
        .iter()
        .filter(|v| !is_null(v))
        .cloned()
        .collect();

    let freq = frequencies(&non_null);

    if unique_count <= 3 {
        warnings.push(Warning::LowCardinality { unique_count });
    }

    let top5_most: Vec<(String, usize)> = freq.iter().take(5).map(|(k, &v)| (k.clone(), v)).collect();
    let top5_least: Vec<(String, usize)> = freq
        .iter()
        .rev()
        .take(5)
        .map(|(k, &v)| (k.clone(), v))
        .collect();

    let histogram = if opts.histogram {
        Some(freq)
    } else {
        None
    };

    TypeStats::Categorical(CategoricalStats {
        top5_most_frequent: top5_most,
        top5_least_frequent: top5_least,
        histogram,
    })
}

fn boolean_stats(values: &[String]) -> TypeStats {
    let non_null: Vec<String> = values
        .iter()
        .filter(|v| !is_null(v))
        .cloned()
        .collect();

    let mut true_count = 0usize;
    let mut false_count = 0usize;
    for v in &non_null {
        match v.to_lowercase().trim() {
            "true" | "yes" | "1" | "t" | "y" => true_count += 1,
            _ => false_count += 1,
        }
    }

    let freq = frequencies(&non_null);
    let top5: Vec<(String, usize)> = freq.iter().take(5).map(|(k, &v)| (k.clone(), v)).collect();

    TypeStats::Boolean(BooleanStats {
        true_count,
        false_count,
        top5_most_frequent: top5,
    })
}

fn text_stats(values: &[String]) -> TypeStats {
    let non_null: Vec<&str> = values
        .iter()
        .filter(|v| !is_null(v))
        .map(|v| v.as_str())
        .collect();

    let lengths: Vec<usize> = non_null.iter().map(|v| v.len()).collect();
    let min_length = lengths.iter().copied().min().unwrap_or(0);
    let max_length = lengths.iter().copied().max().unwrap_or(0);
    let avg_length = if lengths.is_empty() {
        0.0
    } else {
        lengths.iter().sum::<usize>() as f64 / lengths.len() as f64
    };

    TypeStats::Text(TextStats {
        min_length,
        max_length,
        avg_length,
    })
}
