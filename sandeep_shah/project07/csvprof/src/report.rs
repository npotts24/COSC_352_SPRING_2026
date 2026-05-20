use crate::profiler::ProfileReport;
use crate::stats::{ColumnSummary, FrequencyEntry, InferredType};
use anyhow::Result;

pub trait Formatter {
    fn format(&self, report: &ProfileReport) -> Result<String>;
}

pub struct TextFormatter;
pub struct JsonFormatter;

impl Formatter for TextFormatter {
    fn format(&self, report: &ProfileReport) -> Result<String> {
        let mut out = String::new();

        out.push_str("CSV PROFILE REPORT\n");
        out.push_str("==================\n");
        out.push_str(&format!("Rows: {}\n", report.total_rows));
        out.push_str(&format!("Columns: {}\n\n", report.total_columns));

        for col in &report.columns {
            render_column_text(&mut out, col);
            out.push('\n');
        }

        Ok(out)
    }
}

impl Formatter for JsonFormatter {
    fn format(&self, report: &ProfileReport) -> Result<String> {
        Ok(serde_json::to_string_pretty(report)?)
    }
}

fn render_column_text(out: &mut String, col: &ColumnSummary) {
    out.push_str(&format!("Column: {}\n", col.name));
    out.push_str(&format!("  Inferred type: {:?}\n", col.inferred_type));
    out.push_str(&format!("  Row count: {}\n", col.row_count));
    out.push_str(&format!("  Null count: {}\n", col.null_count));
    out.push_str(&format!("  Null %: {:.2}%\n", col.null_percent));
    out.push_str(&format!("  Unique values: {}\n", col.unique_count));

    if col.mixed_type_warning {
        out.push_str("  Warning: mixed-type values detected\n");
    }
    if col.constant_column_warning {
        out.push_str("  Warning: constant column detected\n");
    }

    match col.inferred_type {
        InferredType::Integer | InferredType::Float => {
            if let Some(n) = &col.numeric {
                out.push_str(&format!("  Min: {:.4}\n", n.min));
                out.push_str(&format!("  Max: {:.4}\n", n.max));
                out.push_str(&format!("  Mean: {:.4}\n", n.mean));
                out.push_str(&format!("  Median: {:.4}\n", n.median));
                out.push_str(&format!("  Std dev: {:.4}\n", n.std_dev));
                if let Some(v) = n.p5 {
                    out.push_str(&format!("  P5: {:.4}\n", v));
                }
                if let Some(v) = n.p25 {
                    out.push_str(&format!("  P25: {:.4}\n", v));
                }
                if let Some(v) = n.p75 {
                    out.push_str(&format!("  P75: {:.4}\n", v));
                }
                if let Some(v) = n.p95 {
                    out.push_str(&format!("  P95: {:.4}\n", v));
                }
                out.push_str(&format!("  Outliers (IQR rule): {}\n", n.outlier_count));
            }
        }
        InferredType::Date => {
            if let Some(d) = &col.date {
                out.push_str(&format!("  Min date: {}\n", d.min));
                out.push_str(&format!("  Max date: {}\n", d.max));
            }
        }
        InferredType::Text => {
            if let Some(t) = &col.text {
                out.push_str(&format!("  Shortest length: {}\n", t.shortest_len));
                out.push_str(&format!("  Longest length: {}\n", t.longest_len));
            }
        }
        InferredType::Categorical | InferredType::Boolean => {
            if let Some(most) = &col.top_5_most_frequent {
                out.push_str("  Top 5 most frequent:\n");
                render_freq_list(out, most);
            }
            if let Some(least) = &col.top_5_least_frequent {
                out.push_str("  Top 5 least frequent:\n");
                render_freq_list(out, least);
            }
            if let Some(hist) = &col.histogram {
                out.push_str("  Histogram:\n");
                render_histogram(out, hist);
            }
        }
        InferredType::Empty => {
            out.push_str("  Column contains only null/missing values\n");
        }
    }
}

fn render_freq_list(out: &mut String, entries: &[FrequencyEntry]) {
    for e in entries {
        out.push_str(&format!("    - {}: {}\n", e.value, e.count));
    }
}

fn render_histogram(out: &mut String, entries: &[FrequencyEntry]) {
    let max_count = entries.iter().map(|e| e.count).max().unwrap_or(1);

    for e in entries {
        let bar_len = ((e.count as f64 / max_count as f64) * 30.0).round() as usize;
        let bar = "#".repeat(bar_len.max(1));
        out.push_str(&format!(
            "    {:<20} | {:<30} ({})\n",
            e.value, bar, e.count
        ));
    }
}
