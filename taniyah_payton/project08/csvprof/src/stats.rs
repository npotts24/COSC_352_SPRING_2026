use indexmap::IndexMap;

/// Compute mean of a float slice.
pub fn mean(values: &[f64]) -> Option<f64> {
    if values.is_empty() {
        return None;
    }
    Some(values.iter().sum::<f64>() / values.len() as f64)
}

/// Compute population standard deviation.
pub fn std_dev(values: &[f64]) -> Option<f64> {
    let m = mean(values)?;
    let variance = values.iter().map(|v| (v - m).powi(2)).sum::<f64>() / values.len() as f64;
    Some(variance.sqrt())
}

/// Compute a percentile (0–100) via linear interpolation.
pub fn percentile(sorted: &[f64], p: f64) -> Option<f64> {
    if sorted.is_empty() {
        return None;
    }
    if sorted.len() == 1 {
        return Some(sorted[0]);
    }
    let idx = (p / 100.0) * (sorted.len() - 1) as f64;
    let lo = idx.floor() as usize;
    let hi = idx.ceil() as usize;
    let frac = idx - lo as f64;
    Some(sorted[lo] + frac * (sorted[hi] - sorted[lo]))
}

/// Compute median (p50).
pub fn median(sorted: &[f64]) -> Option<f64> {
    percentile(sorted, 50.0)
}

/// Count value frequencies; returns an IndexMap sorted descending by count.
pub fn frequencies(values: &[String]) -> IndexMap<String, usize> {
    let mut map: IndexMap<String, usize> = IndexMap::new();
    for v in values {
        *map.entry(v.clone()).or_insert(0) += 1;
    }
    map.sort_by(|_, a, _, b| b.cmp(a));
    map
}

/// IQR-based outlier detection. Returns indices of outlier values.
pub fn find_outlier_count(sorted: &[f64]) -> usize {
    if sorted.len() < 4 {
        return 0;
    }
    let q1 = percentile(sorted, 25.0).unwrap_or(0.0);
    let q3 = percentile(sorted, 75.0).unwrap_or(0.0);
    let iqr = q3 - q1;
    let lo = q1 - 1.5 * iqr;
    let hi = q3 + 1.5 * iqr;
    sorted.iter().filter(|&&v| v < lo || v > hi).count()
}
