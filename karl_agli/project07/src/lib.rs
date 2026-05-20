//! Library exports from project07 (csvprof)
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub enum ColumnType { Integer, Float, Boolean, Date, Categorical, Text }

#[derive(Debug)]
pub struct ColumnProfile {
    pub name: String,
    pub col_type: ColumnType,
    pub total_count: usize,
    pub null_count: usize,
    pub unique_values: usize,
    pub min_numeric: Option<f64>,
    pub max_numeric: Option<f64>,
    pub mean: Option<f64>,
    pub std_dev: Option<f64>,
    pub median: Option<f64>,
    pub min_str_len: Option<usize>,
    pub max_str_len: Option<usize>,
    pub top_values: Vec<(String, usize)>,
    pub is_constant: bool,
    pub has_mixed_types: bool,
}

impl ColumnProfile {
    pub fn new(name: String) -> Self {
        ColumnProfile { name, col_type: ColumnType::Text, total_count: 0,
            null_count: 0, unique_values: 0, min_numeric: None, max_numeric: None,
            mean: None, std_dev: None, median: None, min_str_len: None,
            max_str_len: None, top_values: Vec::new(), is_constant: false,
            has_mixed_types: false }
    }
}

pub trait ColumnAnalyzer {
    fn analyze(values: Vec<String>) -> ColumnProfile;
}

pub struct DefaultColumnAnalyzer;
impl ColumnAnalyzer for DefaultColumnAnalyzer {
    fn analyze(values: Vec<String>) -> ColumnProfile { analyze_column(values) }
}

#[derive(Debug)]
pub enum CsvProfError {
    Io(std::io::Error),
    Csv(csv::Error),
    MissingColumn(String),
    ParseError(String),
}

impl std::fmt::Display for CsvProfError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CsvProfError::Io(e) => write!(f, "I/O error: {}", e),
            CsvProfError::Csv(e) => write!(f, "CSV error: {}", e),
            CsvProfError::MissingColumn(c) => write!(f, "Missing column: {}", c),
            CsvProfError::ParseError(m) => write!(f, "Parse error: {}", m),
        }
    }
}
impl From<std::io::Error> for CsvProfError {
    fn from(e: std::io::Error) -> Self { CsvProfError::Io(e) }
}
impl From<csv::Error> for CsvProfError {
    fn from(e: csv::Error) -> Self { CsvProfError::Csv(e) }
}

pub fn infer_type(value: &str) -> ColumnType {
    if value.is_empty() { return ColumnType::Text; }
    if value.parse::<i64>().is_ok() { return ColumnType::Integer; }
    if value.parse::<f64>().is_ok() { return ColumnType::Float; }
    let lower = value.to_lowercase();
    if lower == "true" || lower == "false" || lower == "t" || lower == "f" { return ColumnType::Boolean; }
    ColumnType::Text
}

pub fn read_csv_columns(path: &str) -> Result<(Vec<String>, Vec<Vec<String>>), CsvProfError> {
    use csv::ReaderBuilder;
    use std::fs::File;
    let file = File::open(path)?;
    let mut rdr = ReaderBuilder::new().from_reader(file);
    let headers: Vec<String> = rdr.headers()?.iter().map(|h| h.to_string()).collect();
    let mut columns: Vec<Vec<String>> = vec![Vec::new(); headers.len()];
    for result in rdr.records() {
        let record = result?;
        for (i, field) in record.iter().enumerate() {
            if i < columns.len() { columns[i].push(field.to_string()); }
        }
    }
    Ok((headers, columns))
}

pub fn analyze_column(values: Vec<String>) -> ColumnProfile {
    let mut profile = ColumnProfile::new(String::new());
    profile.total_count = values.len();
    let mut value_counts: HashMap<String, usize> = HashMap::new();
    let mut numeric_values: Vec<f64> = Vec::new();
    let mut type_counts: HashMap<String, usize> = HashMap::new();
    let mut str_lengths: Vec<usize> = Vec::new();
    for val in &values {
        let t = val.trim();
        if t.is_empty() { profile.null_count += 1; continue; }
        *value_counts.entry(t.to_string()).or_insert(0) += 1;
        str_lengths.push(t.len());
        let inf = infer_type(t);
        *type_counts.entry(format!("{:?}", inf)).or_insert(0) += 1;
        if let Ok(n) = t.parse::<f64>() { numeric_values.push(n); }
    }
    profile.unique_values = value_counts.len();
    profile.is_constant = value_counts.len() == 1;
    profile.has_mixed_types = type_counts.len() > 1;
    if let Some(&max_c) = type_counts.values().max() {
        for (tn, &c) in &type_counts {
            if c == max_c {
                profile.col_type = match tn.as_str() {
                    "Integer" => ColumnType::Integer, "Float" => ColumnType::Float,
                    "Boolean" => ColumnType::Boolean, "Date" => ColumnType::Date,
                    _ => if value_counts.len() < 20 { ColumnType::Categorical } else { ColumnType::Text },
                }; break;
            }
        }
    }
    if !numeric_values.is_empty() {
        numeric_values.sort_by(|a, b| a.partial_cmp(b).unwrap());
        profile.min_numeric = Some(numeric_values[0]);
        profile.max_numeric = Some(*numeric_values.last().unwrap());
        let sum: f64 = numeric_values.iter().sum();
        let mean = sum / numeric_values.len() as f64;
        profile.mean = Some(mean);
        let var: f64 = numeric_values.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / numeric_values.len() as f64;
        profile.std_dev = Some(var.sqrt());
        let mid = numeric_values.len() / 2;
        profile.median = if numeric_values.len() % 2 == 0 { Some((numeric_values[mid-1]+numeric_values[mid])/2.0) } else { Some(numeric_values[mid]) };
    }
    if !str_lengths.is_empty() { profile.min_str_len = str_lengths.iter().min().copied(); profile.max_str_len = str_lengths.iter().max().copied(); }
    let mut sc: Vec<_> = value_counts.into_iter().collect();
    sc.sort_by(|a, b| b.1.cmp(&a.1));
    profile.top_values = sc.into_iter().take(5).collect();
    profile
}
