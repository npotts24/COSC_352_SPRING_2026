/// Human-readable table rendering and JSON output for column profiles.
use comfy_table::{modifiers::UTF8_ROUND_CORNERS, presets::UTF8_FULL, Cell, Color, Table};
use serde_json;

use crate::types::*;

/// Render all column profiles to stdout in the requested format.
pub fn render(profiles: &[ColumnProfile], json: bool) {
    if json {
        render_json(profiles);
    } else {
        render_tables(profiles);
    }
}

// ── Table rendering ──────────────────────────────────────────────────────────

fn render_tables(profiles: &[ColumnProfile]) {
    // Summary table
    println!();
    let mut summary = Table::new();
    summary
        .load_preset(UTF8_FULL)
        .apply_modifier(UTF8_ROUND_CORNERS)
        .set_header(vec![
            "Column",
            "Type",
            "Rows",
            "Nulls",
            "Null %",
            "Unique",
            "Warnings",
        ]);

    for p in profiles {
        let null_pct = if p.row_count > 0 {
            format!("{:.1}%", p.null_count as f64 / p.row_count as f64 * 100.0)
        } else {
            "N/A".into()
        };
        let warnings = format_warnings(&p.quality);
        summary.add_row(vec![
            Cell::new(&p.name),
            Cell::new(&p.inferred_type.to_string()),
            Cell::new(p.row_count),
            Cell::new(p.null_count),
            Cell::new(&null_pct),
            Cell::new(p.unique_count),
            if warnings.is_empty() {
                Cell::new("—")
            } else {
                Cell::new(&warnings).fg(Color::Yellow)
            },
        ]);
    }
    println!("╔══ SUMMARY ══╗");
    println!("{summary}");
    println!();

    // Detailed per-column sections
    for p in profiles {
        print_column_detail(p);
    }
}

fn print_column_detail(p: &ColumnProfile) {
    let mut tbl = Table::new();
    tbl.load_preset(UTF8_FULL)
        .apply_modifier(UTF8_ROUND_CORNERS);
    tbl.set_header(vec!["Metric", "Value"]);

    tbl.add_row(vec!["Inferred type", &p.inferred_type.to_string()]);
    tbl.add_row(vec![
        "Row count",
        &p.row_count.to_string(),
    ]);
    tbl.add_row(vec![
        "Null count",
        &p.null_count.to_string(),
    ]);
    let null_pct = if p.row_count > 0 {
        format!("{:.2}%", p.null_count as f64 / p.row_count as f64 * 100.0)
    } else {
        "N/A".into()
    };
    tbl.add_row(vec!["Null %", &null_pct]);
    tbl.add_row(vec![
        "Unique values",
        &p.unique_count.to_string(),
    ]);

    // Numeric stats
    if let Some(ref ns) = p.numeric_stats {
        tbl.add_row(vec!["Min", &format_f64(ns.min)]);
        tbl.add_row(vec!["Max", &format_f64(ns.max)]);
        tbl.add_row(vec!["Mean", &format_f64(ns.mean)]);
        tbl.add_row(vec!["Median", &format_f64(ns.median)]);
        tbl.add_row(vec!["Std dev", &format_f64(ns.std_dev)]);
        if let Some(ref pct) = ns.percentiles {
            tbl.add_row(vec!["p5", &format_f64(pct.p5)]);
            tbl.add_row(vec!["p25", &format_f64(pct.p25)]);
            tbl.add_row(vec!["p75", &format_f64(pct.p75)]);
            tbl.add_row(vec!["p95", &format_f64(pct.p95)]);
        }
    }

    // Date stats
    if let Some(ref ds) = p.date_stats {
        tbl.add_row(vec!["Min date", &ds.min.to_string()]);
        tbl.add_row(vec!["Max date", &ds.max.to_string()]);
    }

    // Text stats
    if let Some(ref ts) = p.text_stats {
        tbl.add_row(vec!["Shortest string", &ts.min_length.to_string()]);
        tbl.add_row(vec!["Longest string", &ts.max_length.to_string()]);
    }

    // Categorical stats
    if let Some(ref cs) = p.categorical_stats {
        let most = cs
            .top_5_most
            .iter()
            .map(|e| format!("{} ({})", e.value, e.count))
            .collect::<Vec<_>>()
            .join(", ");
        tbl.add_row(vec!["Top-5 most frequent", &most]);

        let least = cs
            .top_5_least
            .iter()
            .map(|e| format!("{} ({})", e.value, e.count))
            .collect::<Vec<_>>()
            .join(", ");
        tbl.add_row(vec!["Top-5 least frequent", &least]);

        if let Some(ref hist) = cs.histogram {
            println!();
            print_histogram(&p.name, hist);
        }
    }

    // Quality warnings
    let warnings = format_warnings(&p.quality);
    if !warnings.is_empty() {
        tbl.add_row(vec!["⚠ Warnings", &warnings]);
    }

    println!("── Column: {} ──", p.name);
    println!("{tbl}");
    println!();
}

fn print_histogram(col_name: &str, entries: &[FrequencyEntry]) {
    let max_count = entries.iter().map(|e| e.count).max().unwrap_or(1);
    let bar_width = 40usize;

    println!("  Histogram for \"{col_name}\":");
    for e in entries {
        let bar_len = (e.count as f64 / max_count as f64 * bar_width as f64).round() as usize;
        let bar: String = "█".repeat(bar_len);
        println!("  {:<20} {:>6} │{}", e.value, e.count, bar);
    }
}

fn format_warnings(q: &QualityFlags) -> String {
    let mut parts = Vec::new();
    if q.has_mixed_types {
        parts.push("mixed types");
    }
    if q.is_constant {
        parts.push("constant column");
    }
    if q.high_null_pct {
        parts.push("high null %");
    }
    if let Some(n) = q.outlier_count {
        if n > 0 {
            parts.push("outliers detected");
        }
    }
    if q.low_cardinality {
        parts.push("low cardinality");
    }
    parts.join("; ")
}

fn format_f64(v: f64) -> String {
    if v == v.trunc() && v.abs() < 1e15 {
        format!("{:.0}", v)
    } else {
        format!("{:.4}", v)
    }
}

// ── JSON rendering ───────────────────────────────────────────────────────────

fn render_json(profiles: &[ColumnProfile]) {
    let json_profiles: Vec<serde_json::Value> = profiles.iter().map(profile_to_json).collect();
    let output = serde_json::to_string_pretty(&json_profiles).unwrap_or_default();
    println!("{output}");
}

fn profile_to_json(p: &ColumnProfile) -> serde_json::Value {
    let mut map = serde_json::Map::new();
    map.insert("column".into(), serde_json::Value::String(p.name.clone()));
    map.insert(
        "inferred_type".into(),
        serde_json::Value::String(p.inferred_type.to_string()),
    );
    map.insert("row_count".into(), serde_json::json!(p.row_count));
    map.insert("null_count".into(), serde_json::json!(p.null_count));
    map.insert(
        "null_pct".into(),
        serde_json::json!(if p.row_count > 0 {
            p.null_count as f64 / p.row_count as f64 * 100.0
        } else {
            0.0
        }),
    );
    map.insert("unique_count".into(), serde_json::json!(p.unique_count));

    if let Some(ref ns) = p.numeric_stats {
        map.insert("min".into(), serde_json::json!(ns.min));
        map.insert("max".into(), serde_json::json!(ns.max));
        map.insert("mean".into(), serde_json::json!(ns.mean));
        map.insert("median".into(), serde_json::json!(ns.median));
        map.insert("std_dev".into(), serde_json::json!(ns.std_dev));
        if let Some(ref pct) = ns.percentiles {
            map.insert("p5".into(), serde_json::json!(pct.p5));
            map.insert("p25".into(), serde_json::json!(pct.p25));
            map.insert("p75".into(), serde_json::json!(pct.p75));
            map.insert("p95".into(), serde_json::json!(pct.p95));
        }
    }

    if let Some(ref ds) = p.date_stats {
        map.insert(
            "min_date".into(),
            serde_json::Value::String(ds.min.to_string()),
        );
        map.insert(
            "max_date".into(),
            serde_json::Value::String(ds.max.to_string()),
        );
    }

    if let Some(ref ts) = p.text_stats {
        map.insert("min_string_length".into(), serde_json::json!(ts.min_length));
        map.insert("max_string_length".into(), serde_json::json!(ts.max_length));
    }

    if let Some(ref cs) = p.categorical_stats {
        let most: Vec<serde_json::Value> = cs
            .top_5_most
            .iter()
            .map(|e| serde_json::json!({"value": e.value, "count": e.count}))
            .collect();
        map.insert("top_5_most_frequent".into(), serde_json::json!(most));

        let least: Vec<serde_json::Value> = cs
            .top_5_least
            .iter()
            .map(|e| serde_json::json!({"value": e.value, "count": e.count}))
            .collect();
        map.insert("top_5_least_frequent".into(), serde_json::json!(least));
    }

    // Quality
    let mut warnings = Vec::new();
    if p.quality.has_mixed_types {
        warnings.push("mixed types");
    }
    if p.quality.is_constant {
        warnings.push("constant column");
    }
    if p.quality.high_null_pct {
        warnings.push("high null %");
    }
    if let Some(n) = p.quality.outlier_count {
        if n > 0 {
            warnings.push("outliers detected");
        }
    }
    if p.quality.low_cardinality {
        warnings.push("low cardinality");
    }
    map.insert("warnings".into(), serde_json::json!(warnings));

    serde_json::Value::Object(map)
}
