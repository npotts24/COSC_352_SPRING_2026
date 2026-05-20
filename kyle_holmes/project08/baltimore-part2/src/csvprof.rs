use clap::Parser;
use csv::ReaderBuilder;
use indexmap::IndexMap;
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufReader, Read};
use std::path::PathBuf;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    let mut col_stats: IndexMap<usize, ColStats> = IndexMap::new();

    let reader: Box<dyn Read> = if cli.file == PathBuf::from("-") {
        Box::new(io::stdin())
    } else {
        Box::new(BufReader::new(File::open(&cli.file)?))
    };

    let mut rdr = ReaderBuilder::new().flexible(true).from_reader(reader);
    let headers = rdr.headers()?.clone();
    for (i, h) in headers.iter().enumerate() {
        col_stats.insert(i, ColStats::new(h.to_string()));
    }

    for result in rdr.records() {
        let record = result?;
        for (i, val) in record.iter().enumerate() {
            if let Some(s) = col_stats.get_mut(&i) {
                s.feed(val.trim());
            }
        }
    }

    let stats: Vec<ColStats> = col_stats.into_values().collect();
    render_report(stats, cli.percentiles, cli.histogram);
    Ok(())
}

/// CSV Profiling CLI Tool
#[derive(Parser, Debug)]
#[clap(
    name = "csvprof",
    override_usage = "csvprof [OPTIONS] <FILE>",
    disable_version_flag = true,
    help_template = "csvprof [OPTIONS] <FILE>\n\nArguments:\n  <FILE>                    Path to input CSV file (use `-` for stdin)\n\nOptions: Defined by you\n"
)]
struct Cli {
    /// Path to input CSV file
    file: PathBuf,

    /// Include percentiles
    #[clap(long)]
    percentiles: bool,

    /// Include histogram
    #[clap(long)]
    histogram: bool,
}

#[derive(Debug, Clone, PartialEq)]
enum ColType {
    Integer, Float, Boolean, Date, Categorical, Text,
}

impl std::fmt::Display for ColType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            ColType::Integer => "integer",
            ColType::Float => "float",
            ColType::Boolean => "boolean",
            ColType::Date => "date",
            ColType::Categorical => "categorical",
            ColType::Text => "text",
        };
        write!(f, "{s}")
    }
}

fn is_bool(s: &str) -> bool {
    matches!(s.to_lowercase().as_str(), "true"|"false"|"yes"|"no"|"1"|"0"|"t"|"f"|"y"|"n")
}

fn is_date(s: &str) -> bool {
    let patterns = [
        "%Y-%m-%d", "%Y/%m/%d", "%d/%m/%Y", "%m/%d/%Y",
        "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S",
    ];
    for pat in &patterns {
        if chrono::NaiveDate::parse_from_str(s, pat).is_ok()
            || chrono::NaiveDateTime::parse_from_str(s, pat).is_ok()
        {
            return true;
        }
    }
    false
}

struct ColStats {
    name: String,
    row_count: u64,
    null_count: u64,
    int_votes: u64,
    float_votes: u64,
    bool_votes: u64,
    date_votes: u64,
    numeric_values: Vec<f64>,
    min_len: usize,
    max_len: usize,
    value_counts: HashMap<String, u64>,
    type_set: std::collections::HashSet<&'static str>,
}

impl ColStats {
    fn new(name: String) -> Self {
        ColStats {
            name,
            row_count: 0,
            null_count: 0,
            int_votes: 0,
            float_votes: 0,
            bool_votes: 0,
            date_votes: 0,
            numeric_values: Vec::new(),
            min_len: usize::MAX,
            max_len: 0,
            value_counts: HashMap::new(),
            type_set: std::collections::HashSet::new(),
        }
    }

    fn feed(&mut self, val: &str) {
        self.row_count += 1;
        if val.is_empty() {
            self.null_count += 1;
            return;
        }
        let l = val.len();
        if l < self.min_len { self.min_len = l; }
        if l > self.max_len { self.max_len = l; }
        if self.value_counts.len() < 10_000 {
            *self.value_counts.entry(val.to_string()).or_insert(0) += 1;
        }
        if val.parse::<i64>().is_ok() {
            self.int_votes += 1;
            self.type_set.insert("integer");
            self.numeric_values.push(val.parse::<f64>().unwrap());
        } else if val.parse::<f64>().is_ok() {
            self.float_votes += 1;
            self.type_set.insert("float");
            self.numeric_values.push(val.parse::<f64>().unwrap());
        } else if is_bool(val) {
            self.bool_votes += 1;
            self.type_set.insert("boolean");
        } else if is_date(val) {
            self.date_votes += 1;
            self.type_set.insert("date");
        } else {
            self.type_set.insert("text");
        }
    }

    fn inferred_type(&self) -> ColType {
        let non_null = self.row_count - self.null_count;
        if non_null == 0 { return ColType::Text; }
        let threshold = (non_null as f64 * 0.85) as u64;
        if self.int_votes >= threshold { return ColType::Integer; }
        if self.int_votes + self.float_votes >= threshold { return ColType::Float; }
        if self.bool_votes >= threshold { return ColType::Boolean; }
        if self.date_votes >= threshold { return ColType::Date; }
        let unique = self.value_counts.len() as f64;
        let total = non_null as f64;
        if unique / total < 0.5 && unique <= 100.0 { return ColType::Categorical; }
        ColType::Text
    }

    fn is_mixed(&self) -> bool {
        self.type_set.len() > 1
            && !(self.type_set.contains("integer") && self.type_set.contains("float"))
    }

    fn is_constant(&self) -> bool {
        self.value_counts.len() <= 1 && self.row_count > 1
    }
}

fn percentile(sorted: &[f64], p: f64) -> f64 {
    if sorted.is_empty() { return f64::NAN; }
    let idx = p / 100.0 * (sorted.len() - 1) as f64;
    let lo = idx.floor() as usize;
    let hi = idx.ceil() as usize;
    if lo == hi { sorted[lo] } else { sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo as f64) }
}

fn mean(v: &[f64]) -> f64 {
    if v.is_empty() { return f64::NAN; }
    v.iter().sum::<f64>() / v.len() as f64
}

fn median(sorted: &[f64]) -> f64 { percentile(sorted, 50.0) }

fn std_dev(v: &[f64]) -> f64 {
    if v.len() < 2 { return f64::NAN; }
    let m = mean(v);
    let var = v.iter().map(|x| (x - m).powi(2)).sum::<f64>() / (v.len() - 1) as f64;
    var.sqrt()
}

fn render_report(stats: Vec<ColStats>, show_pct: bool, show_hist: bool) {
    let total_rows = stats.first().map(|s| s.row_count).unwrap_or(0);
    println!("==============================================================");
    println!("  CSV PROFILE REPORT  ({} rows total)", total_rows);
    println!("==============================================================");
    println!();

    for col in &stats {
        let col_type = col.inferred_type();
        let non_null = col.row_count - col.null_count;
        let null_pct = if col.row_count > 0 { col.null_count as f64 / col.row_count as f64 * 100.0 } else { 0.0 };
        let unique = col.value_counts.len();

        println!("--- {} ---", col.name);
        println!("  Inferred type  : {}", col_type);
        println!("  Row count      : {}  |  Null count: {} ({:.1}%)", col.row_count, col.null_count, null_pct);
        println!("  Unique values  : {}", unique);

        if col.is_constant() {
            println!("  WARNING: CONSTANT COLUMN - all values are identical");
        }
        if col.is_mixed() {
            let mut types: Vec<&&str> = col.type_set.iter().collect();
            types.sort();
            println!("  WARNING: MIXED TYPES detected: {:?}", types);
        }

        match col_type {
            ColType::Integer | ColType::Float => {
                let mut sorted = col.numeric_values.clone();
                sorted.sort_by(|a, b| a.partial_cmp(b).unwrap());
                let mn = sorted.first().copied().unwrap_or(f64::NAN);
                let mx = sorted.last().copied().unwrap_or(f64::NAN);
                println!("  Min / Max      : {} / {}", mn, mx);
                println!("  Mean / Median  : {:.4} / {:.4}", mean(&sorted), median(&sorted));
                println!("  Std dev        : {:.4}", std_dev(&sorted));
                let q1 = percentile(&sorted, 25.0);
                let q3 = percentile(&sorted, 75.0);
                let iqr = q3 - q1;
                let outliers = sorted.iter().filter(|&&x| x < q1 - 1.5 * iqr || x > q3 + 1.5 * iqr).count();
                if outliers > 0 {
                    println!("  WARNING: Outliers (IQR method): {}", outliers);
                }
                if show_pct && sorted.len() >= 4 {
                    println!("  p5/p25/p75/p95 : {:.4} / {:.4} / {:.4} / {:.4}",
                        percentile(&sorted, 5.0), percentile(&sorted, 25.0),
                        percentile(&sorted, 75.0), percentile(&sorted, 95.0));
                }
            }
            ColType::Date => {
                let mut dates: Vec<&String> = col.value_counts.keys().collect();
                dates.sort();
                if let (Some(first), Some(last)) = (dates.first(), dates.last()) {
                    println!("  Min / Max date : {} / {}", first, last);
                }
            }
            ColType::Boolean => {
                let true_count: u64 = col.value_counts.iter()
                    .filter(|(k, _)| matches!(k.to_lowercase().as_str(), "true"|"yes"|"1"|"t"|"y"))
                    .map(|(_, v)| v).sum();
                let false_count = non_null - true_count;
                println!("  True / False   : {} / {}", true_count, false_count);
                let mut counts: Vec<(&String, &u64)> = col.value_counts.iter().collect();
                counts.sort_by(|a, b| b.1.cmp(a.1));
                let top5: Vec<String> = counts.iter().take(5).map(|(k, v)| format!("{}={}", k, v)).collect();
                println!("  Top values     : {}", top5.join(", "));
            }
            ColType::Categorical => {
                let mut counts: Vec<(&String, &u64)> = col.value_counts.iter().collect();
                counts.sort_by(|a, b| b.1.cmp(a.1));
                let top5: Vec<String> = counts.iter().take(5).map(|(k, v)| format!("{}={}", k, v)).collect();
                let bot5: Vec<String> = counts.iter().rev().take(5).map(|(k, v)| format!("{}={}", k, v)).collect();
                println!("  Top-5 frequent : {}", top5.join(", "));
                println!("  Bot-5 frequent : {}", bot5.join(", "));
                if show_hist {
                    println!("  Histogram (top 10):");
                    let max_count = counts.first().map(|(_, v)| **v).unwrap_or(1);
                    for (k, v) in counts.iter().take(10) {
                        let bar_len = (**v as f64 / max_count as f64 * 30.0) as usize;
                        let bar = "#".repeat(bar_len);
                        println!("    {:>20} | {} {}", k, bar, v);
                    }
                }
            }
            ColType::Text => {
                let min_l = if col.min_len == usize::MAX { 0 } else { col.min_len };
                println!("  String length  : min={} / max={}", min_l, col.max_len);
            }
        }

        println!("--------------------------------------------------------------");
        println!();
    }
}