use std::fmt::Write;

use crate::stats::format_numeric;
use crate::types::{ColumnReport, DatasetReport, OutputFormat};

pub fn render(report: &DatasetReport, format: OutputFormat) -> anyhow::Result<String> {
    match format {
        OutputFormat::Markdown => Ok(render_markdown(report)),
        OutputFormat::Json => Ok(serde_json::to_string_pretty(report)?),
    }
}

pub fn render_markdown(report: &DatasetReport) -> String {
    let mut output = String::new();
    let _ = writeln!(output, "# csvprof report");
    let _ = writeln!(output);
    let _ = writeln!(output, "Rows profiled: **{}**", report.rows);

    for column in &report.columns {
        let _ = writeln!(output);
        let _ = writeln!(output, "## {}", escape(&column.name));
        let _ = writeln!(
            output,
            "- Type: {}",
            format!("{:?}", column.inferred_type).to_lowercase()
        );
        let _ = writeln!(output, "- Rows: {}", column.rows);
        let _ = writeln!(output, "- Nulls: {}", column.null_count);
        let _ = writeln!(output, "- Non-null: {}", column.non_null_count);
        let _ = writeln!(output, "- Distinct: {}", render_distinct(column));

        if column.min.is_some() || column.max.is_some() {
            let _ = writeln!(
                output,
                "- Min/Max: {} / {}",
                cell(column.min.as_deref()),
                cell(column.max.as_deref())
            );
        }

        if column.mean.is_some() || column.median.is_some() || column.std_dev.is_some() {
            let _ = writeln!(
                output,
                "- Mean/Median/Std Dev: {} / {} / {}",
                render_optional_f64(column.mean),
                render_optional_f64(column.median),
                render_optional_f64(column.std_dev)
            );
        }

        if !column.top_values.is_empty() {
            let _ = writeln!(output, "- Top values: {}", render_top_values(column));
        }

        if !column.percentiles.is_empty() {
            let _ = writeln!(output, "- Percentiles: {}", render_percentiles(column));
        }

        if !column.notes.is_empty() {
            let _ = writeln!(output, "- Notes: {}", render_notes(column));
        }
    }

    output
}

fn render_distinct(column: &ColumnReport) -> String {
    match column.distinct_count {
        Some(value) if column.distinct_is_approximate => format!("~{value}"),
        Some(value) => value.to_string(),
        None => "-".to_string(),
    }
}

fn render_optional_f64(value: Option<f64>) -> String {
    value
        .map(|value| format_numeric(value, crate::types::InferredType::Float))
        .unwrap_or_else(|| "-".to_string())
}

fn render_top_values(column: &ColumnReport) -> String {
    column
        .top_values
        .iter()
        .map(|entry| format!("{} ({})", escape(&entry.value), entry.count))
        .collect::<Vec<_>>()
        .join(", ")
}

fn render_percentiles(column: &ColumnReport) -> String {
    column
        .percentiles
        .iter()
        .map(|item| {
            format!(
                "p{}={}",
                trim_percentile(item.percentile),
                render_optional_f64(Some(item.value))
            )
        })
        .collect::<Vec<_>>()
        .join(", ")
}

fn render_notes(column: &ColumnReport) -> String {
    column
        .notes
        .iter()
        .map(|item| escape(item))
        .collect::<Vec<_>>()
        .join("; ")
}

fn trim_percentile(value: f64) -> String {
    if value.fract().abs() < f64::EPSILON {
        format!("{}", value as u32)
    } else {
        format!("{value:.1}")
    }
}

fn cell(value: Option<&str>) -> String {
    value.map(escape).unwrap_or_else(|| "-".to_string())
}

fn escape(value: &str) -> String {
    value.replace('\n', " ")
}
