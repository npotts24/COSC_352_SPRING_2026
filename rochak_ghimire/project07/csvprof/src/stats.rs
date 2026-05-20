pub fn mean(v: &Vec<f64>) -> f64 {
    v.iter().sum::<f64>() / v.len() as f64
}

pub fn min(v: &Vec<f64>) -> f64 {
    v.iter().cloned().fold(f64::INFINITY, f64::min)
}

pub fn max(v: &Vec<f64>) -> f64 {
    v.iter().cloned().fold(f64::NEG_INFINITY, f64::max)
}

pub fn median(v: &mut Vec<f64>) -> f64 {
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let mid = v.len() / 2;
    if v.len() % 2 == 0 {
        (v[mid - 1] + v[mid]) / 2.0
    } else {
        v[mid]
    }
}

pub fn std_dev(v: &Vec<f64>) -> f64 {
    let m = mean(v);
    let variance = v.iter().map(|x| (x - m).powi(2)).sum::<f64>() / v.len() as f64;
    variance.sqrt()
}

pub fn percentile(v: &mut Vec<f64>, p: f64) -> f64 {
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let idx = ((p / 100.0) * v.len() as f64).round() as usize;
    v[idx.min(v.len() - 1)]
}