//! Output rendering for terminal tables and JSON.

use crate::report::{ColumnReport, CsvReport};
use comfy_table::*;
use std::io::Write;

/// Render a CSV report as human-readable terminal tables.
pub fn render_terminal(report: &CsvReport, writer: &mut dyn Write) -> std::io::Result<()> {
    // Summary table
    writeln!(writer)?;
    let mut summary = Table::new();
    summary
        .load_preset(presets::UTF8_HORIZONTAL_ONLY)
        .set_content_arrangement(ContentArrangement::DynamicFullWidth);
    summary.set_header(vec!["File", "Rows", "Columns"]);
    summary.add_row(vec![
        report.file.to_string(),
        report.rows.to_string(),
        report.columns.to_string(),
    ]);
    writeln!(writer, "{}", summary)?;
    writeln!(writer)?;

    // Per-column tables
    for col_report in &report.column_reports {
        render_column_table(col_report, writer)?;
    }

    Ok(())
}

/// Render a single column report as a table.
fn render_column_table(col: &ColumnReport, writer: &mut dyn Write) -> std::io::Result<()> {
    let mut table = Table::new();
    table
        .load_preset(presets::UTF8_HORIZONTAL_ONLY)
        .set_content_arrangement(ContentArrangement::DynamicFullWidth);

    // Header with column name and type
    let title = format!("{} ({})", col.name, col.inferred_type);
    table.set_header(vec![title]);

    // Common stats
    table.add_row(vec!["Row Count", &col.row_count.to_string()]);
    table.add_row(vec!["Null Count", &col.null_count.to_string()]);
    table.add_row(vec![
        "Null %",
        &format!("{:.2}%", col.null_pct),
    ]);
    table.add_row(vec!["Unique Count", &col.unique_count.to_string()]);

    // Warnings
    if col.is_constant {
        table.add_row(vec!["⚠️  Constant", "All non-null values are identical"]);
    }
    if let Some(warning) = &col.mixed_type_warning {
        table.add_row(vec!["⚠️  Mixed Type", warning.as_str()]);
    }

    // Type-specific stats
    if let Some(num_stats) = &col.numeric_stats {
        table.add_row(vec!["Min", &format!("{:.6}", num_stats.min)]);
        table.add_row(vec!["Max", &format!("{:.6}", num_stats.max)]);
        table.add_row(vec!["Mean", &format!("{:.6}", num_stats.mean)]);
        table.add_row(vec!["Median", &format!("{:.6}", num_stats.median)]);
        table.add_row(vec!["Std Dev", &format!("{:.6}", num_stats.std_dev)]);

        if let Some(p5) = num_stats.p5 {
            table.add_row(vec!["P5", &format!("{:.6}", p5)]);
        }
        if let Some(p25) = num_stats.p25 {
            table.add_row(vec!["P25", &format!("{:.6}", p25)]);
        }
        if let Some(p75) = num_stats.p75 {
            table.add_row(vec!["P75", &format!("{:.6}", p75)]);
        }
        if let Some(p95) = num_stats.p95 {
            table.add_row(vec!["P95", &format!("{:.6}", p95)]);
        }
    }

    if let Some(cat_stats) = &col.categorical_stats {
        if !cat_stats.top_values.is_empty() {
            table.add_row(vec!["Top Values", ""]);
            for (value, count) in &cat_stats.top_values {
                table.add_row(vec![
                    &format!("  {}", value),
                    &format!("{} ({}%)", count, ((*count as f64 / col.row_count as f64) * 100.0) as u32),
                ]);
            }
        }

        if let Some(bottom) = &cat_stats.bottom_values {
            if !bottom.is_empty() {
                table.add_row(vec!["Bottom Values", ""]);
                for (value, count) in bottom {
                    table.add_row(vec![
                        &format!("  {}", value),
                        &format!("{} ({}%)", count, ((*count as f64 / col.row_count as f64) * 100.0) as u32),
                    ]);
                }
            }
        }

        if let Some(hist) = &cat_stats.histogram {
            if !hist.is_empty() {
                table.add_row(vec!["Histogram", ""]);
                let max_count = hist.iter().map(|(_, c)| c).max().copied().unwrap_or(1);
                for (value, count) in hist {
                    let bar_width = if max_count > 0 {
                        (*count as f64 / max_count as f64) * 40.0
                    } else {
                        0.0
                    };
                    let bar = "█".repeat(bar_width as usize);
                    table.add_row(vec![
                        &format!("  {}", value),
                        &format!("{} {}", bar, count),
                    ]);
                }
            }
        }
    }

    if let Some(text_stats) = &col.text_stats {
        table.add_row(vec!["Min Length", &text_stats.min_length.to_string()]);
        table.add_row(vec!["Max Length", &text_stats.max_length.to_string()]);
        table.add_row(vec!["Avg Length", &format!("{:.2}", text_stats.avg_length)]);
    }

    if let Some(date_stats) = &col.date_stats {
        if let Some(min_date) = &date_stats.min_date {
            table.add_row(vec!["Min Date", min_date]);
        }
        if let Some(max_date) = &date_stats.max_date {
            table.add_row(vec!["Max Date", max_date]);
        }
    }

    writeln!(writer, "{}", table)?;
    writeln!(writer)?;

    Ok(())
}

/// Render a CSV report as JSON.
pub fn render_json(report: &CsvReport, writer: &mut dyn Write) -> std::io::Result<()> {
    let json = serde_json::to_string_pretty(&report)
        .map_err(std::io::Error::other)?;
    writeln!(writer, "{}", json)?;
    Ok(())
}
