use ordered_float::OrderedFloat;
use std::cmp::Ordering;
use std::collections::HashMap;

pub fn mean(values: &[f64]) -> Option<f64> {
    (!values.is_empty()).then(|| values.iter().sum::<f64>() / values.len() as f64)
}

pub fn median(values: &mut Vec<f64>) -> Option<f64> {
    if values.is_empty() {
        return None;
    }

    values.sort_by_key(|v| OrderedFloat(*v));
    let n = values.len();
    if n % 2 == 1 {
        Some(values[n / 2])
    } else {
        Some((values[n / 2 - 1] + values[n / 2]) / 2.0)
    }
}

pub fn std_dev(values: &[f64]) -> Option<f64> {
    let avg = mean(values)?;
    let variance = values
        .iter()
        .map(|v| {
            let d = *v - avg;
            d * d
        })
        .sum::<f64>()
        / values.len() as f64;
    Some(variance.sqrt())
}

pub fn percentile(sorted: &[f64], p: f64) -> Option<f64> {
    if sorted.is_empty() || !(0.0..=100.0).contains(&p) {
        return None;
    }

    if sorted.len() == 1 {
        return Some(sorted[0]);
    }

    let rank = (p / 100.0) * (sorted.len() - 1) as f64;
    let lower = rank.floor() as usize;
    let upper = rank.ceil() as usize;

    if lower == upper {
        Some(sorted[lower])
    } else {
        let weight = rank - lower as f64;
        Some(sorted[lower] * (1.0 - weight) + sorted[upper] * weight)
    }
}

pub fn frequency_map(values: &[String]) -> HashMap<String, usize> {
    values.iter().fold(HashMap::new(), |mut acc, value| {
        *acc.entry(value.clone()).or_insert(0) += 1;
        acc
    })
}

pub fn top_n(map: &HashMap<String, usize>, n: usize, ascending: bool) -> Vec<(String, usize)> {
    let mut entries: Vec<(String, usize)> = map.iter().map(|(k, v)| (k.clone(), *v)).collect();

    entries.sort_by(|(ka, va), (kb, vb)| {
        let count_cmp = if ascending { va.cmp(vb) } else { vb.cmp(va) };
        if count_cmp == Ordering::Equal {
            ka.cmp(kb)
        } else {
            count_cmp
        }
    });

    entries.into_iter().take(n).collect()
}
