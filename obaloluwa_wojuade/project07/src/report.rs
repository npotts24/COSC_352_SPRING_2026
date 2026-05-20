use crate::cli::Args;
use crate::column::ColumnProfile;
use crate::error::Result;
use comfy_table::{presets::UTF8_FULL, ContentArrangement, Table};

pub struct Reporter;

impl Reporter {
    pub fn print_table(profiles: &[ColumnProfile], args: &Args) {
        profiles.iter().for_each(|profile| {
            let mut table = Table::new();
            table
                .load_preset(UTF8_FULL)
                .set_content_arrangement(ContentArrangement::Dynamic)
                .set_header(vec![
                    format!("{}  [{}]", profile.name, profile.inferred_type),
                    String::new(),
                ]);

            add_row(&mut table, "row_count", profile.row_count.to_string());
            add_row(
                &mut table,
                "null_count",
                format!(
                    "{} ({:.2}%)",
                    profile.null_count,
                    null_percent(profile.null_count, profile.row_count)
                ),
            );
            add_row(&mut table, "unique_count", profile.unique_count.to_string());

            add_opt_string(&mut table, "min", profile.min.as_deref());
            add_opt_string(&mut table, "max", profile.max.as_deref());
            add_opt_f64(&mut table, "mean", profile.mean);
            add_opt_f64(&mut table, "median", profile.median);
            add_opt_f64(&mut table, "std_dev", profile.std_dev);

            if args.percentiles {
                add_opt_f64(&mut table, "p5", profile.p5);
                add_opt_f64(&mut table, "p25", profile.p25);
                add_opt_f64(&mut table, "p75", profile.p75);
                add_opt_f64(&mut table, "p95", profile.p95);
            }

            if !profile.top5_most_frequent.is_empty() {
                add_row(
                    &mut table,
                    "top5_most_frequent",
                    fmt_pairs(&profile.top5_most_frequent),
                );
            }
            if !profile.top5_least_frequent.is_empty() {
                add_row(
                    &mut table,
                    "top5_least_frequent",
                    fmt_pairs(&profile.top5_least_frequent),
                );
            }

            if let Some(shortest) = profile.shortest_len {
                add_row(&mut table, "shortest_len", shortest.to_string());
            }
            if let Some(longest) = profile.longest_len {
                add_row(&mut table, "longest_len", longest.to_string());
            }

            if args.histogram && !profile.histogram.is_empty() {
                add_row(&mut table, "histogram", fmt_pairs(&profile.histogram));
            }

            if profile.is_constant {
                add_row(&mut table, "warning", "⚠ CONSTANT COLUMN".to_string());
            }
            if profile.has_mixed_types {
                add_row(&mut table, "warning", "⚠ MIXED TYPES DETECTED".to_string());
            }

            println!("{table}");
        });
    }

    pub fn print_json(profiles: &[ColumnProfile]) -> Result<()> {
        let json = serde_json::to_string_pretty(profiles)
            .map_err(|e| std::io::Error::other(format!("JSON serialization failed: {e}")))?;
        println!("{json}");
        Ok(())
    }
}

pub fn add_row(table: &mut Table, field: &str, value: String) {
    table.add_row(vec![field.to_string(), value]);
}

pub fn add_opt_string(table: &mut Table, field: &str, value: Option<&str>) {
    if let Some(value) = value {
        add_row(table, field, value.to_string());
    }
}

pub fn add_opt_f64(table: &mut Table, field: &str, value: Option<f64>) {
    if let Some(value) = value {
        add_row(table, field, format!("{value:.2}"));
    }
}

pub fn fmt_pairs(pairs: &[(String, usize)]) -> String {
    pairs
        .iter()
        .map(|(v, c)| format!("{v}:{c}"))
        .collect::<Vec<String>>()
        .join(", ")
}

pub fn null_percent(null_count: usize, row_count: usize) -> f64 {
    if row_count == 0 {
        0.0
    } else {
        (null_count as f64 / row_count as f64) * 100.0
    }
}
