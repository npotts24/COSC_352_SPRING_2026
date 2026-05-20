use colored::Colorize;
use comfy_table::{presets::UTF8_FULL, Cell, CellAlignment, Color, ContentArrangement, Table};

use crate::profile::{BooleanStats, CategoricalStats, ColumnProfile, NumericStats, TypeStats};

pub fn print_report(profiles: &[ColumnProfile], file_name: &str) {
    println!();
    println!(
        "{}",
        format!(" csvprof — {file_name} ").on_bright_blue().bold().white()
    );
    println!(
        "  {} columns  •  {} rows",
        profiles.len().to_string().bold(),
        profiles
            .first()
            .map(|p| p.row_count.to_string())
            .unwrap_or_else(|| "0".to_string())
            .bold()
    );
    println!();

    for (idx, profile) in profiles.iter().enumerate() {
        print_column(idx + 1, profile);
    }
}

fn print_column(idx: usize, p: &ColumnProfile) {
    // ── Header ──────────────────────────────────────────────────────────────
    println!(
        "{}",
        format!(" [{idx}] {} ", p.name).on_bright_black().white().bold()
    );

    // ── Summary table ────────────────────────────────────────────────────────
    let mut summary = Table::new();
    summary
        .load_preset(UTF8_FULL)
        .set_content_arrangement(ContentArrangement::Dynamic)
        .set_header(vec![
            Cell::new("Field").fg(Color::Cyan).set_alignment(CellAlignment::Left),
            Cell::new("Value").fg(Color::Cyan),
        ]);

    summary.add_row(vec!["Inferred Type", &p.inferred_type.to_string()]);
    summary.add_row(vec!["Row Count", &p.row_count.to_string()]);
    summary.add_row(vec![
        "Null Count",
        &format!("{} ({:.1}%)", p.null_count, p.null_pct),
    ]);
    summary.add_row(vec!["Unique Values", &p.unique_count.to_string()]);

    println!("{summary}");

    // ── Type-specific stats ───────────────────────────────────────────────────
    if let Some(ts) = &p.type_stats {
        match ts {
            TypeStats::Numeric(n) => print_numeric(n),
            TypeStats::Date(d) => {
                let mut t = make_table();
                t.add_row(vec!["Min Date", &d.min]);
                t.add_row(vec!["Max Date", &d.max]);
                println!("{t}");
            }
            TypeStats::Categorical(c) => print_categorical(c),
            TypeStats::Boolean(b) => print_boolean(b),
            TypeStats::Text(tx) => {
                let mut t = make_table();
                t.add_row(vec!["Min Length", &tx.min_length.to_string()]);
                t.add_row(vec!["Max Length", &tx.max_length.to_string()]);
                t.add_row(vec!["Avg Length", &format!("{:.1}", tx.avg_length)]);
                println!("{t}");
            }
        }
    }

    // ── Warnings ─────────────────────────────────────────────────────────────
    if !p.warnings.is_empty() {
        println!("  {}", "⚠ Warnings".yellow().bold());
        for w in &p.warnings {
            println!("    {} {}", "•".yellow(), format!("{w}").yellow());
        }
    }

    println!();
}

fn print_numeric(n: &NumericStats) {
    let mut t = make_table();
    t.add_row(vec!["Min", &fmt_f64(n.min)]);
    t.add_row(vec!["Max", &fmt_f64(n.max)]);
    t.add_row(vec!["Mean", &fmt_f64(n.mean)]);
    t.add_row(vec!["Median", &fmt_f64(n.median)]);
    t.add_row(vec!["Std Dev", &fmt_f64(n.std_dev)]);
    if let Some(v) = n.p5  { t.add_row(vec!["P5",  &fmt_f64(v)]); }
    if let Some(v) = n.p25 { t.add_row(vec!["P25", &fmt_f64(v)]); }
    if let Some(v) = n.p75 { t.add_row(vec!["P75", &fmt_f64(v)]); }
    if let Some(v) = n.p95 { t.add_row(vec!["P95", &fmt_f64(v)]); }
    if n.outlier_count > 0 {
        t.add_row(vec![
            "Outliers (IQR)",
            &n.outlier_count.to_string(),
        ]);
    }
    println!("{t}");
}

fn print_categorical(c: &CategoricalStats) {
    if !c.top5_most_frequent.is_empty() {
        println!("  {}", "Top 5 Most Frequent".bright_cyan());
        let mut t = make_table();
        for (val, cnt) in &c.top5_most_frequent {
            t.add_row(vec![val.as_str(), &cnt.to_string()]);
        }
        println!("{t}");
    }
    if !c.top5_least_frequent.is_empty() {
        println!("  {}", "Top 5 Least Frequent".bright_cyan());
        let mut t = make_table();
        for (val, cnt) in &c.top5_least_frequent {
            t.add_row(vec![val.as_str(), &cnt.to_string()]);
        }
        println!("{t}");
    }
    if let Some(hist) = &c.histogram {
        println!("  {}", "Value Frequency Histogram".bright_cyan());
        let max_count = hist.values().copied().max().unwrap_or(1);
        let bar_width = 30usize;
        for (val, cnt) in hist {
            let filled = ((*cnt as f64 / max_count as f64) * bar_width as f64).round() as usize;
            let bar: String = "█".repeat(filled) + &" ".repeat(bar_width - filled);
            println!("  {:<20} │{}│ {}", truncate(val, 20), bar, cnt);
        }
        println!();
    }
}

fn print_boolean(b: &BooleanStats) {
    let mut t = make_table();
    t.add_row(vec!["True Count",  &b.true_count.to_string()]);
    t.add_row(vec!["False Count", &b.false_count.to_string()]);
    for (val, cnt) in &b.top5_most_frequent {
        t.add_row(vec![val.as_str(), &cnt.to_string()]);
    }
    println!("{t}");
}

// ── Utilities ─────────────────────────────────────────────────────────────────

fn make_table() -> Table {
    let mut t = Table::new();
    t.load_preset(UTF8_FULL)
        .set_content_arrangement(ContentArrangement::Dynamic);
    t
}

fn fmt_f64(v: f64) -> String {
    if v.fract() == 0.0 && v.abs() < 1e15 {
        format!("{:.0}", v)
    } else {
        format!("{:.4}", v)
    }
}

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("{}…", &s[..max - 1])
    }
}
