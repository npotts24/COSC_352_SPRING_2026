//! The serializable artifact the profiler produces.
//!
//! [`Report`] is a list of [`ColumnReport`] rows plus some envelope
//! metadata. It implements `Serialize` for JSON output, and exposes a
//! `render_table` method that returns a human-readable terminal table.

use crate::types::ColumnType;
use colored::Colorize;
use comfy_table::{Cell, ContentArrangement, Table};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NumericStats {
    pub min:           f64,
    pub max:           f64,
    pub mean:          f64,
    pub median:        f64,
    pub std_dev:       f64,
    pub percentiles:   Option<[f64; 4]>, // p5, p25, p75, p95
    pub outlier_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopK {
    pub most:      Vec<(String, usize)>,
    pub least:     Vec<(String, usize)>,
    pub histogram: Option<Vec<(String, usize)>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ColumnReport {
    pub name:          String,
    pub inferred:      ColumnType,
    pub row_count:     usize,
    pub null_count:    usize,
    pub null_pct:      f64,
    pub unique_count:  Option<usize>,
    pub numeric_stats: Option<NumericStats>,
    pub date_range:    Option<(String, String)>,
    pub min_str_len:   Option<usize>,
    pub max_str_len:   Option<usize>,
    pub top_k:         Option<TopK>,
    pub warnings:      Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Report {
    pub source:   String,
    pub rows:     usize,
    pub columns:  Vec<ColumnReport>,
}

impl Report {
    /// JSON text, pretty-printed.
    pub fn to_json(&self) -> crate::Result<String> {
        Ok(serde_json::to_string_pretty(self)?)
    }

    /// Human-readable terminal output using `comfy-table` + `colored`.
    pub fn render_table(&self) -> String {
        let mut out = String::new();
        out.push_str(&format!(
            "\n{}\n{} {}\n{} {}\n\n",
            "CSV Profile Report".bold().underline(),
            "source:".dimmed(),
            self.source,
            "rows:  ".dimmed(),
            self.rows,
        ));

        let mut t = Table::new();
        t.load_preset(comfy_table::presets::UTF8_FULL)
         .set_content_arrangement(ContentArrangement::Dynamic)
         .set_header(vec![
             Cell::new("column").add_attribute(comfy_table::Attribute::Bold),
             Cell::new("type").add_attribute(comfy_table::Attribute::Bold),
             Cell::new("rows").add_attribute(comfy_table::Attribute::Bold),
             Cell::new("nulls").add_attribute(comfy_table::Attribute::Bold),
             Cell::new("null %").add_attribute(comfy_table::Attribute::Bold),
             Cell::new("unique").add_attribute(comfy_table::Attribute::Bold),
             Cell::new("min / max").add_attribute(comfy_table::Attribute::Bold),
             Cell::new("mean ± std").add_attribute(comfy_table::Attribute::Bold),
         ]);

        for c in &self.columns {
            let unique = c.unique_count
                .map(|u| u.to_string())
                .unwrap_or_else(|| "saturated".into());

            let minmax = if let Some(n) = &c.numeric_stats {
                format!("{:.3} / {:.3}", n.min, n.max)
            } else if let Some((a, b)) = &c.date_range {
                format!("{} / {}", a, b)
            } else if let (Some(a), Some(b)) = (c.min_str_len, c.max_str_len) {
                format!("len {} / {}", a, b)
            } else {
                "-".into()
            };

            let meanstd = c.numeric_stats.as_ref()
                .map(|n| format!("{:.3} ± {:.3}", n.mean, n.std_dev))
                .unwrap_or_else(|| "-".into());

            t.add_row(vec![
                Cell::new(&c.name),
                Cell::new(format!("{}", c.inferred)),
                Cell::new(c.row_count.to_string()),
                Cell::new(c.null_count.to_string()),
                Cell::new(format!("{:.2}", c.null_pct)),
                Cell::new(unique),
                Cell::new(minmax),
                Cell::new(meanstd),
            ]);
        }

        out.push_str(&t.to_string());
        out.push('\n');

        // Extra sections: percentiles, top-k, warnings.
        for c in &self.columns {
            let mut column_extras: Vec<String> = Vec::new();

            if let Some(n) = &c.numeric_stats {
                column_extras.push(format!(
                    "median: {:.3}   outliers (1.5*IQR): {}",
                    n.median, n.outlier_count,
                ));
                if let Some([p5, p25, p75, p95]) = n.percentiles {
                    column_extras.push(format!(
                        "p5: {:.3}   p25: {:.3}   p75: {:.3}   p95: {:.3}",
                        p5, p25, p75, p95,
                    ));
                }
            }

            if let Some(tk) = &c.top_k {
                if !tk.most.is_empty() {
                    let s: Vec<String> = tk.most.iter()
                        .map(|(v, n)| format!("{v}({n})")).collect();
                    column_extras.push(format!("top-5 most:   {}", s.join(", ")));
                }
                if !tk.least.is_empty() {
                    let s: Vec<String> = tk.least.iter()
                        .map(|(v, n)| format!("{v}({n})")).collect();
                    column_extras.push(format!("top-5 least:  {}", s.join(", ")));
                }
                if let Some(h) = &tk.histogram {
                    let s: Vec<String> = h.iter()
                        .map(|(v, n)| format!("{v}={n}")).collect();
                    column_extras.push(format!("histogram:    {}", s.join(", ")));
                }
            }

            for w in &c.warnings {
                column_extras.push(format!("{} {}", "WARN".yellow().bold(), w));
            }

            if !column_extras.is_empty() {
                out.push_str(&format!("\n{}:\n", c.name.bold()));
                for line in column_extras {
                    out.push_str(&format!("  {line}\n"));
                }
            }
        }

        out
    }
}
