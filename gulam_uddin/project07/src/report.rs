use crate::cli::{Args, OutputFormat};
use crate::error::ProfilingError;
use crate::types::{ColumnType, FileProfile};
use comfy_table::{modifiers::UTF8_ROUND_CORNERS, presets::UTF8_FULL, Cell, Color, Table};

/// Render the completed profile to stdout.
pub fn render(profile: &FileProfile, args: &Args) -> Result<(), ProfilingError> {
    match args.format {
        OutputFormat::Table => render_table(profile, args),
        OutputFormat::Json => render_json(profile),
    }
}

// ---------------------------------------------------------------------------
// JSON output
// ---------------------------------------------------------------------------

fn render_json(profile: &FileProfile) -> Result<(), ProfilingError> {
    let json = serde_json::to_string_pretty(profile)?;
    println!("{json}");
    Ok(())
}

// ---------------------------------------------------------------------------
// Human-readable table output
// ---------------------------------------------------------------------------

fn render_table(profile: &FileProfile, args: &Args) -> Result<(), ProfilingError> {
    println!();
    println!("╔══════════════════════════════════════════════════╗");
    println!("║             CSV PROFILING REPORT                ║");
    println!("╚══════════════════════════════════════════════════╝");
    println!();
    println!("  File:    {}", profile.file_name);
    println!("  Rows:    {}", profile.total_rows);
    println!("  Columns: {}", profile.total_columns);
    println!();

    for col in &profile.columns {
        render_column_table(col, args);
    }

    Ok(())
}

/// Helper: push a metric row into the table.
fn add_metric(table: &mut Table, metric: &str, value: &str) {
    table.add_row(vec![Cell::new(metric), Cell::new(value)]);
}

/// Helper: push a warning row into the table.
fn add_warning(table: &mut Table, msg: &str) {
    table.add_row(vec![
        Cell::new("⚠ Warning").fg(Color::Yellow),
        Cell::new(msg),
    ]);
}

fn render_column_table(col: &crate::types::ColumnProfile, args: &Args) {
    println!("──────────────────────────────────────────────────");
    println!("  Column: {}", col.name);
    println!("──────────────────────────────────────────────────");

    let mut table = Table::new();
    table
        .load_preset(UTF8_FULL)
        .apply_modifier(UTF8_ROUND_CORNERS);

    table.set_header(vec![
        Cell::new("Metric").fg(Color::Cyan),
        Cell::new("Value").fg(Color::Cyan),
    ]);

    // Universal fields
    add_metric(&mut table, "Inferred Type", &col.inferred_type.to_string());
    add_metric(&mut table, "Row Count", &col.row_count.to_string());
    add_metric(&mut table, "Null Count", &col.null_count.to_string());
    add_metric(&mut table, "Null %", &format!("{:.2}%", col.null_percent));
    add_metric(&mut table, "Unique Values", &col.unique_count.to_string());

    // Type-specific fields
    match col.inferred_type {
        ColumnType::Integer | ColumnType::Float => {
            if let Some(v) = col.min_numeric {
                add_metric(&mut table, "Min", &format_number(v, col.inferred_type));
            }
            if let Some(v) = col.max_numeric {
                add_metric(&mut table, "Max", &format_number(v, col.inferred_type));
            }
            if let Some(v) = col.mean {
                add_metric(&mut table, "Mean", &format!("{v:.4}"));
            }
            if let Some(v) = col.median {
                add_metric(&mut table, "Median", &format_number(v, col.inferred_type));
            }
            if let Some(v) = col.std_dev {
                add_metric(&mut table, "Std Dev", &format!("{v:.4}"));
            }
            if args.percentiles {
                if let Some(v) = col.p5 {
                    add_metric(&mut table, "P5", &format_number(v, col.inferred_type));
                }
                if let Some(v) = col.p25 {
                    add_metric(&mut table, "P25", &format_number(v, col.inferred_type));
                }
                if let Some(v) = col.p75 {
                    add_metric(&mut table, "P75", &format_number(v, col.inferred_type));
                }
                if let Some(v) = col.p95 {
                    add_metric(&mut table, "P95", &format_number(v, col.inferred_type));
                }
            }
        }
        ColumnType::Date => {
            if let Some(ref v) = col.min_date {
                add_metric(&mut table, "Min Date", v);
            }
            if let Some(ref v) = col.max_date {
                add_metric(&mut table, "Max Date", v);
            }
        }
        ColumnType::Boolean | ColumnType::Categorical => {
            if let Some(ref top) = col.top_values {
                let display = top
                    .iter()
                    .map(|(k, c)| format!("{k} ({c})"))
                    .collect::<Vec<_>>()
                    .join(", ");
                add_metric(&mut table, "Top Values", &display);
            }
            if let Some(ref bottom) = col.bottom_values {
                let display = bottom
                    .iter()
                    .map(|(k, c)| format!("{k} ({c})"))
                    .collect::<Vec<_>>()
                    .join(", ");
                add_metric(&mut table, "Least Frequent", &display);
            }
        }
        ColumnType::Text => {
            if let Some(v) = col.shortest_length {
                add_metric(&mut table, "Shortest Length", &v.to_string());
            }
            if let Some(v) = col.longest_length {
                add_metric(&mut table, "Longest Length", &v.to_string());
            }
        }
    }

    // Histogram
    if let Some(ref hist) = col.histogram {
        let display = hist
            .iter()
            .map(|(k, c)| format!("{k}: {c}"))
            .collect::<Vec<_>>()
            .join(" | ");
        add_metric(&mut table, "Histogram", &display);
    }

    // Warnings
    for w in &col.warnings {
        add_warning(&mut table, w);
    }

    println!("{table}");
    println!();
}

fn format_number(v: f64, col_type: ColumnType) -> String {
    match col_type {
        ColumnType::Integer => {
            if v == v.trunc() && v.abs() < i64::MAX as f64 {
                format!("{}", v as i64)
            } else {
                format!("{v}")
            }
        }
        _ => format!("{v:.4}"),
    }
}