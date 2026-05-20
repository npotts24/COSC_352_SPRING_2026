//! Human-readable terminal report renderer.

use colored::Colorize;
use comfy_table::{Attribute, Cell, Color, ContentArrangement, Table};

use crate::types::{ColumnProfile, FileProfile, InferredType};

// ── colour helpers ────────────────────────────────────────────────────────────

#[allow(dead_code)]
fn type_color(t: &InferredType) -> Color {
    match t {
        InferredType::Integer     => Color::Cyan,
        InferredType::Float       => Color::Blue,
        InferredType::Boolean     => Color::Magenta,
        InferredType::Date        => Color::Yellow,
        InferredType::Categorical => Color::Green,
        InferredType::Text        => Color::White,
    }
}

fn null_pct_cell(pct: f64) -> Cell {
    let s = format!("{:.1}%", pct);
    if pct >= 50.0 {
        Cell::new(s).fg(Color::Red)
    } else if pct >= 10.0 {
        Cell::new(s).fg(Color::Yellow)
    } else {
        Cell::new(s)
    }
}

// ── public entry point ────────────────────────────────────────────────────────

/// Print the full human-readable report to stdout.
pub fn print_report(fp: &FileProfile, show_percentiles: bool, show_histogram: bool) {
    // ── banner ────────────────────────────────────────────────────────────
    println!();
    println!(
        "{}",
        format!(
            "  csvprof  ·  {}  ·  {} rows  ·  {} columns  ",
            fp.file, fp.total_rows, fp.total_cols
        )
        .black()
        .on_bright_white()
        .bold()
    );
    println!();

    for col in &fp.columns {
        print_column(col, show_percentiles, show_histogram);
        println!();
    }
}

fn print_column(col: &ColumnProfile, show_percentiles: bool, show_histogram: bool) {
    // ── column header ─────────────────────────────────────────────────────
    let type_label = format!("[{}]", col.inferred_type);
    println!(
        "  {}  {}",
        col.name.bold().underline(),
        type_label.truecolor(120, 180, 255),
    );

    // ── summary table ─────────────────────────────────────────────────────
    let mut table = Table::new();
    table
        .load_preset(comfy_table::presets::UTF8_BORDERS_ONLY)
        .set_content_arrangement(ContentArrangement::Dynamic);

    table.set_header(vec![
        Cell::new("Field").add_attribute(Attribute::Bold),
        Cell::new("Value").add_attribute(Attribute::Bold),
    ]);

    // rows / nulls
    table.add_row(vec![Cell::new("Row count"), Cell::new(col.row_count)]);
    table.add_row(vec![
        Cell::new("Null count"),
        Cell::new(col.null_count),
    ]);
    table.add_row(vec![Cell::new("Null %"), null_pct_cell(col.null_pct)]);
    table.add_row(vec![Cell::new("Unique values"), Cell::new(col.unique_count)]);

    // numeric
    if let Some(ns) = &col.numeric_stats {
        table.add_row(vec![Cell::new("Min"), Cell::new(fmt_f64(ns.min))]);
        table.add_row(vec![Cell::new("Max"), Cell::new(fmt_f64(ns.max))]);
        table.add_row(vec![Cell::new("Mean"), Cell::new(fmt_f64(ns.mean))]);
        table.add_row(vec![Cell::new("Median"), Cell::new(fmt_f64(ns.median))]);
        table.add_row(vec![Cell::new("Std Dev"), Cell::new(fmt_f64(ns.std_dev))]);
        if show_percentiles {
            if let (Some(p5), Some(p25), Some(p75), Some(p95)) =
                (ns.p5, ns.p25, ns.p75, ns.p95)
            {
                table.add_row(vec![Cell::new("p5"),  Cell::new(fmt_f64(p5))]);
                table.add_row(vec![Cell::new("p25"), Cell::new(fmt_f64(p25))]);
                table.add_row(vec![Cell::new("p75"), Cell::new(fmt_f64(p75))]);
                table.add_row(vec![Cell::new("p95"), Cell::new(fmt_f64(p95))]);
            }
        }
    }

    // text
    if let Some(ts) = &col.text_stats {
        table.add_row(vec![Cell::new("Shortest string"), Cell::new(ts.min_length)]);
        table.add_row(vec![Cell::new("Longest string"),  Cell::new(ts.max_length)]);
        table.add_row(vec![
            Cell::new("Avg string length"),
            Cell::new(format!("{:.1}", ts.avg_length)),
        ]);
    }

    println!("{table}");

    // ── categorical freq table ────────────────────────────────────────────
    if let Some(cs) = &col.categorical_stats {
        if !cs.top_5_most_frequent.is_empty() {
            println!("  {} most frequent:", "Top-5".bold());
            let ft = small_freq_table(&cs.top_5_most_frequent);
            println!("{ft}");
        }
        if !cs.top_5_least_frequent.is_empty()
            && cs.top_5_least_frequent != cs.top_5_most_frequent
        {
            println!("  {} least frequent:", "Top-5".bold());
            let ft = small_freq_table(&cs.top_5_least_frequent);
            println!("{ft}");
        }
        if show_histogram {
            if let Some(hist) = &cs.histogram {
                println!("  {} frequency histogram:", "Full".bold());
                print_bar_chart(hist);
            }
        }
    }

    // ── warnings ──────────────────────────────────────────────────────────
    for w in &col.warnings {
        println!("  {} {}", "⚠".yellow(), w.yellow());
    }
}

// ── helpers ───────────────────────────────────────────────────────────────────

fn fmt_f64(v: f64) -> String {
    if v.fract() == 0.0 && v.abs() < 1e15 {
        format!("{}", v as i64)
    } else {
        format!("{:.4}", v)
    }
}

fn small_freq_table(pairs: &[(String, u64)]) -> Table {
    let mut t = Table::new();
    t.load_preset(comfy_table::presets::NOTHING)
     .set_content_arrangement(ContentArrangement::Dynamic);
    t.set_header(vec![
        Cell::new("  Value").add_attribute(Attribute::Bold),
        Cell::new("Count").add_attribute(Attribute::Bold),
    ]);
    for (val, cnt) in pairs {
        t.add_row(vec![Cell::new(format!("  {}", val)), Cell::new(cnt)]);
    }
    t
}

fn print_bar_chart(hist: &[(String, u64)]) {
    let max_cnt = hist.iter().map(|(_, c)| *c).max().unwrap_or(1);
    let bar_width = 30usize;
    for (val, cnt) in hist {
        let filled = (*cnt as f64 / max_cnt as f64 * bar_width as f64).round() as usize;
        let bar = "█".repeat(filled) + &"░".repeat(bar_width - filled);
        println!("  {:>20}  {}  {}", val, bar.cyan(), cnt);
    }
}
