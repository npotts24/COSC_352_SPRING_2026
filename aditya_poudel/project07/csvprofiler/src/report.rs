use colored::Colorize;
use comfy_table::{Cell, ContentArrangement, Table, Attribute};
use crate::stats::{ColumnReport, FreqEntry};

pub struct ReportRenderer {
    pub json: bool,
    pub no_color: bool,
}

impl ReportRenderer {
    pub fn render(&self, reports: &[ColumnReport], file_path: &str) {
        if self.json {
            println!("{}", serde_json::to_string_pretty(reports).unwrap());
            return;
        }

        self.render_human(reports, file_path);
    }

    fn render_human(&self, reports: &[ColumnReport], file_path: &str) {
        // ── Header banner ──────────────────────────────────────────────
        let row_count = reports.first().map(|r| r.row_count).unwrap_or(0);
        let col_count = reports.len();

        println!();
        let banner = format!(
            " csvprof │ {} │ {} rows × {} columns ",
            file_path, row_count, col_count
        );
        if self.no_color {
            println!("{}", banner);
        } else {
            println!("{}", banner.on_bright_blue().white().bold());
        }
        println!();

        for report in reports {
            self.render_column(report);
        }
    }

    fn render_column(&self, r: &ColumnReport) {
        // Column heading
        let heading = format!("▶  {} ({})", r.name, r.inferred_type);
        if self.no_color {
            println!("{}", heading);
        } else {
            println!("{}", heading.bold().cyan());
        }

        let mut table = Table::new();
        table.set_content_arrangement(ContentArrangement::Dynamic);
        table.set_header(vec![
            Cell::new("Field").add_attribute(Attribute::Bold),
            Cell::new("Value").add_attribute(Attribute::Bold),
        ]);

        // Core quality fields — always shown.
        table.add_row(vec!["Row count", &r.row_count.to_string()]);
        table.add_row(vec![
            "Null count",
            &format!("{} ({:.1}%)", r.null_count, r.null_pct),
        ]);

        let unique_label = if r.unique_count_exact { "Unique values" } else { "Unique values (≥)" };
        if let Some(u) = r.unique_count {
            table.add_row(vec![unique_label, &u.to_string()]);
        }

        // Min / max.
        if let (Some(mn), Some(mx)) = (&r.min, &r.max) {
            table.add_row(vec!["Min", mn]);
            table.add_row(vec!["Max", mx]);
        }

        // Numeric stats.
        if let Some(v) = r.mean {
            table.add_row(vec!["Mean", &fmt_f64(v)]);
        }
        if let Some(v) = r.median {
            table.add_row(vec!["Median", &fmt_f64(v)]);
        }
        if let Some(v) = r.std_dev {
            table.add_row(vec!["Std dev", &fmt_f64(v)]);
        }

        // Percentiles.
        if let Some(v) = r.p5 {
            table.add_row(vec!["p5", &fmt_f64(v)]);
        }
        if let Some(v) = r.p25 {
            table.add_row(vec!["p25", &fmt_f64(v)]);
        }
        if let Some(v) = r.p75 {
            table.add_row(vec!["p75", &fmt_f64(v)]);
        }
        if let Some(v) = r.p95 {
            table.add_row(vec!["p95", &fmt_f64(v)]);
        }

        // String lengths.
        if let (Some(mn), Some(mx)) = (r.str_min_len, r.str_max_len) {
            table.add_row(vec!["Shortest string", &mn.to_string()]);
            table.add_row(vec!["Longest string", &mx.to_string()]);
        }

        println!("{table}");

        // Top/bottom frequency tables.
        if let Some(top) = &r.top5_most_frequent {
            if !top.is_empty() {
                println!("  {} most frequent:", "Top-5".bold());
                self.render_freq_table(top);
            }
        }
        if let Some(bot) = &r.top5_least_frequent {
            if !bot.is_empty() {
                println!("  {} least frequent:", "Top-5".bold());
                self.render_freq_table(bot);
            }
        }

        // Histogram.
        if let Some(hist) = &r.histogram {
            if !hist.is_empty() {
                println!("  {}:", "Histogram".bold());
                self.render_histogram(hist);
            }
        }

        // Warnings.
        if !r.warnings.is_empty() {
            for w in &r.warnings {
                let msg = format!("  ⚠  {}", w);
                if self.no_color {
                    println!("{}", msg);
                } else {
                    println!("{}", msg.yellow());
                }
            }
        }

        println!();
    }

    fn render_freq_table(&self, entries: &[FreqEntry]) {
        let mut t = Table::new();
        t.set_content_arrangement(ContentArrangement::Dynamic);
        t.set_header(vec!["Value", "Count", "%"]);
        for e in entries {
            t.add_row(vec![
                e.value.clone(),
                e.count.to_string(),
                format!("{:.1}", e.pct),
            ]);
        }
        // Indent by printing with prefix.
        for line in t.to_string().lines() {
            println!("    {}", line);
        }
    }

    fn render_histogram(&self, entries: &[FreqEntry]) {
        let max_count = entries.iter().map(|e| e.count).max().unwrap_or(1);
        let bar_width = 30usize;

        for e in entries {
            let filled = (e.count as f64 / max_count as f64 * bar_width as f64).round() as usize;
            let bar: String = "█".repeat(filled) + &"░".repeat(bar_width - filled);
            let line = format!("    {:>20} │{}│ {} ({:.1}%)", e.value, bar, e.count, e.pct);
            if self.no_color {
                println!("{}", line);
            } else {
                println!("{}", line.bright_green());
            }
        }
    }
}

fn fmt_f64(v: f64) -> String {
    if v.fract().abs() < 1e-9 && v.abs() < 1e12 {
        format!("{:.0}", v)
    } else {
        format!("{:.4}", v)
    }
}