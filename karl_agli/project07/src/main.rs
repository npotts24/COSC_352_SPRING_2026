use clap::Parser;
use colored::Colorize;
use comfy_table::{Table, Cell, Color};
use csv::ReaderBuilder;
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufRead, BufReader};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "csvprof")]
#[command(about = "CSV Profiling CLI Tool - Analyze CSV data quality and statistics")]
struct Cli {
    /// Path to input CSV file (use '-' for stdin)
    file: String,

    #[arg(short, long)]
    percentiles: bool,

    #[arg(short, long)]
    histogram: bool,
}

#[derive(Debug, Clone)]
enum ColumnType {
    Integer,
    Float,
    Boolean,
    Date,
    Categorical,
    Text,
}

#[derive(Debug)]
struct ColumnProfile {
    name: String,
    col_type: ColumnType,
    total_count: usize,
    null_count: usize,
    unique_values: usize,
    min_numeric: Option<f64>,
    max_numeric: Option<f64>,
    mean: Option<f64>,
    std_dev: Option<f64>,
    median: Option<f64>,
    min_str_len: Option<usize>,
    max_str_len: Option<usize>,
    top_values: Vec<(String, usize)>,
    is_constant: bool,
    has_mixed_types: bool,
}

impl ColumnProfile {
    fn new(name: String) -> Self {
        ColumnProfile {
            name,
            col_type: ColumnType::Text,
            total_count: 0,
            null_count: 0,
            unique_values: 0,
            min_numeric: None,
            max_numeric: None,
            mean: None,
            std_dev: None,
            median: None,
            min_str_len: None,
            max_str_len: None,
            top_values: Vec::new(),
            is_constant: false,
            has_mixed_types: false,
        }
    }
}

fn infer_type(value: &str) -> ColumnType {
    if value.is_empty() {
        return ColumnType::Text;
    }

    if value.parse::<i64>().is_ok() {
        return ColumnType::Integer;
    }

    if value.parse::<f64>().is_ok() {
        return ColumnType::Float;
    }

    let lower = value.to_lowercase();
    if lower == "true" || lower == "false" || lower == "t" || lower == "f" {
        return ColumnType::Boolean;
    }

    ColumnType::Text
}

fn analyze_column(values: Vec<String>) -> ColumnProfile {
    let mut profile = ColumnProfile::new(String::new());
    profile.total_count = values.len();

    let mut value_counts: HashMap<String, usize> = HashMap::new();
    let mut numeric_values: Vec<f64> = Vec::new();
    let mut type_counts: HashMap<String, usize> = HashMap::new();
    let mut str_lengths: Vec<usize> = Vec::new();

    for val in &values {
        let trimmed = val.trim();

        if trimmed.is_empty() {
            profile.null_count += 1;
            continue;
        }

        *value_counts.entry(trimmed.to_string()).or_insert(0) += 1;
        str_lengths.push(trimmed.len());

        let inferred = infer_type(trimmed);
        let type_name = format!("{:?}", inferred);
        *type_counts.entry(type_name).or_insert(0) += 1;

        if let Ok(num) = trimmed.parse::<f64>() {
            numeric_values.push(num);
        }
    }

    profile.unique_values = value_counts.len();
    profile.is_constant = value_counts.len() == 1;
    profile.has_mixed_types = type_counts.len() > 1;

    if let Some(&max_type_count) = type_counts.values().max() {
        for (type_name, &count) in &type_counts {
            if count == max_type_count {
                profile.col_type = match type_name.as_str() {
                    "Integer" => ColumnType::Integer,
                    "Float" => ColumnType::Float,
                    "Boolean" => ColumnType::Boolean,
                    "Date" => ColumnType::Date,
                    _ => {
                        if value_counts.len() < 20 {
                            ColumnType::Categorical
                        } else {
                            ColumnType::Text
                        }
                    }
                };
                break;
            }
        }
    }

    if !numeric_values.is_empty() {
        numeric_values.sort_by(|a, b| a.partial_cmp(b).unwrap());
        profile.min_numeric = Some(numeric_values[0]);
        profile.max_numeric = Some(numeric_values[numeric_values.len() - 1]);

        let sum: f64 = numeric_values.iter().sum();
        let mean = sum / numeric_values.len() as f64;
        profile.mean = Some(mean);

        let variance: f64 = numeric_values.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / numeric_values.len() as f64;
        profile.std_dev = Some(variance.sqrt());

        let mid = numeric_values.len() / 2;
        profile.median = if numeric_values.len() % 2 == 0 {
            Some((numeric_values[mid - 1] + numeric_values[mid]) / 2.0)
        } else {
            Some(numeric_values[mid])
        };
    }

    if !str_lengths.is_empty() {
        profile.min_str_len = str_lengths.iter().min().copied();
        profile.max_str_len = str_lengths.iter().max().copied();
    }

    let mut sorted_counts: Vec<_> = value_counts.into_iter().collect();
    sorted_counts.sort_by(|a, b| b.1.cmp(&a.1));
    profile.top_values = sorted_counts.into_iter().take(5).collect();

    profile
}

fn main() -> io::Result<()> {
    let cli = Cli::parse();

    let reader: Box<dyn BufRead> = if cli.file == "-" {
        Box::new(BufReader::new(io::stdin()))
    } else {
        Box::new(BufReader::new(File::open(&cli.file)?))
    };

    let mut csv_reader = ReaderBuilder::new().from_reader(reader);

    let headers = csv_reader.headers()?.clone();
    let mut columns: Vec<Vec<String>> = vec![Vec::new(); headers.len()];

    for result in csv_reader.records() {
        let record = result?;
        for (i, field) in record.iter().enumerate() {
            if i < columns.len() {
                columns[i].push(field.to_string());
            }
        }
    }

    println!("\n{}", "==".repeat(50).bright_cyan());
    println!("{}", "CSV PROFILING REPORT".bright_yellow().bold());
    println!("{}", "==".repeat(50).bright_cyan());
    println!("Total Columns: {}", headers.len());
    println!("Total Rows: {}\n", columns[0].len());

    for (idx, header) in headers.iter().enumerate() {
        let mut profile = analyze_column(columns[idx].clone());
        profile.name = header.to_string();

        let mut table = Table::new();
        table.set_header(vec![Cell::new(&profile.name).fg(Color::Cyan)]);

        table.add_row(vec!["Field", "Value"]);
        table.add_row(vec!["Inferred Type", &format!("{:?}", profile.col_type)]);
        table.add_row(vec!["Row Count", &profile.total_count.to_string()]);
        table.add_row(vec!["Null Count", &profile.null_count.to_string()]);
        table.add_row(vec!["Null %", &format!("{:.2}%", (profile.null_count as f64 / profile.total_count as f64) * 100.0)]);
        table.add_row(vec!["Unique Values", &profile.unique_values.to_string()]);

        if let (Some(min), Some(max)) = (profile.min_numeric, profile.max_numeric) {
            table.add_row(vec!["Min", &format!("{:.2}", min)]);
            table.add_row(vec!["Max", &format!("{:.2}", max)]);
        }

        if let Some(mean) = profile.mean {
            table.add_row(vec!["Mean", &format!("{:.2}", mean)]);
        }

        if let Some(median) = profile.median {
            table.add_row(vec!["Median", &format!("{:.2}", median)]);
        }

        if let Some(std_dev) = profile.std_dev {
            table.add_row(vec!["Std Dev", &format!("{:.2}", std_dev)]);
        }

        if let (Some(min_len), Some(max_len)) = (profile.min_str_len, profile.max_str_len) {
            table.add_row(vec!["Min String Length", &min_len.to_string()]);
            table.add_row(vec!["Max String Length", &max_len.to_string()]);
        }

        if !profile.top_values.is_empty() {
            let top_str = profile.top_values.iter()
                .map(|(v, c)| format!("{} ({})", v, c))
                .collect::<Vec<_>>()
                .join(", ");
            table.add_row(vec!["Top 5 Values", &top_str]);
        }

        if profile.is_constant {
            table.add_row(vec!["⚠ WARNING", "Constant column (all values same)"]);
        }

        if profile.has_mixed_types {
            table.add_row(vec!["⚠ WARNING", "Mixed types detected"]);
        }

        println!("{}", table);
        println!();
    }

    println!("{}", "==".repeat(50).bright_cyan());
    println!("{}", "Report Complete".bright_green().bold());
    println!("{}", "==".repeat(50).bright_cyan());

    Ok(())
}
