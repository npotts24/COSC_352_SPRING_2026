use comfy_table::{Attribute, Cell, Table, presets::UTF8_FULL};

use crate::analysis::Finding;
use crate::join::{PublicSafetyStats, ZipLiquorStats};

pub fn print_zip_table(stats: &[ZipLiquorStats], top_n: usize) {
    println!("=== TOP {} ZIP CODES BY ACTIVE LIQUOR LICENSES ===\n", top_n);

    let mut table = Table::new();
    table.load_preset(UTF8_FULL);
    table.set_header(vec![
        Cell::new("Zip Code").add_attribute(Attribute::Bold),
        Cell::new("Total Licenses").add_attribute(Attribute::Bold),
        Cell::new("Active Licenses").add_attribute(Attribute::Bold),
        Cell::new("Taverns").add_attribute(Attribute::Bold),
        Cell::new("Restaurants").add_attribute(Attribute::Bold),
        Cell::new("Package Goods").add_attribute(Attribute::Bold),
        Cell::new("Avg License Fee").add_attribute(Attribute::Bold),
    ]);

    for stat in stats.iter().take(top_n) {
        table.add_row(vec![
            Cell::new(stat.zip.clone()),
            Cell::new(stat.total_licenses.to_string()),
            Cell::new(stat.active_licenses.to_string()),
            Cell::new(stat.tavern_count.to_string()),
            Cell::new(stat.restaurant_count.to_string()),
            Cell::new(stat.package_goods_count.to_string()),
            Cell::new(format!("${:.2}", stat.avg_license_fee)),
        ]);
    }

    println!("{table}");
}

pub fn print_salary_summary(stats: &PublicSafetyStats) {
    println!("\n=== PUBLIC SAFETY SALARY SUMMARY (FY2024) ===\n");

    let mut table = Table::new();
    table.load_preset(UTF8_FULL);
    table.set_header(vec![
        Cell::new("Metric").add_attribute(Attribute::Bold),
        Cell::new("Value").add_attribute(Attribute::Bold),
    ]);

    table.add_row(vec![
        Cell::new("Total city employees (FY2024)"),
        Cell::new(stats.total_employees.to_string()),
    ]);
    table.add_row(vec![
        Cell::new("Citywide avg annual salary"),
        Cell::new(format!("${:.2}", stats.citywide_avg_salary)),
    ]);
    table.add_row(vec![
        Cell::new("Citywide salary std dev"),
        Cell::new(format!("${:.2}", stats.citywide_salary_std_dev)),
    ]);
    table.add_row(vec![
        Cell::new("Police Dept employees"),
        Cell::new(stats.police_count.to_string()),
    ]);
    table.add_row(vec![
        Cell::new("Police avg salary"),
        Cell::new(format!("${:.2}", stats.police_avg_salary)),
    ]);
    table.add_row(vec![
        Cell::new("Police above citywide avg"),
        Cell::new(format!(
            "{} ({:.1}%)",
            stats.above_avg_police,
            if stats.police_count > 0 {
                stats.above_avg_police as f64 / stats.police_count as f64 * 100.0
            } else {
                0.0
            }
        )),
    ]);
    table.add_row(vec![
        Cell::new("Fire Dept employees"),
        Cell::new(stats.fire_count.to_string()),
    ]);
    table.add_row(vec![
        Cell::new("Fire avg salary"),
        Cell::new(format!("${:.2}", stats.fire_avg_salary)),
    ]);
    table.add_row(vec![
        Cell::new("Fire above citywide avg"),
        Cell::new(format!(
            "{} ({:.1}%)",
            stats.above_avg_fire,
            if stats.fire_count > 0 {
                stats.above_avg_fire as f64 / stats.fire_count as f64 * 100.0
            } else {
                0.0
            }
        )),
    ]);
    table.add_row(vec![
        Cell::new("Public safety above-average earners"),
        Cell::new(stats.above_avg_public_safety.to_string()),
    ]);

    println!("{table}");
}

pub fn print_finding(finding: &Finding) {
    println!("\n=== RESEARCH FINDING ===\n");
    println!("{}", finding.summary);
    println!();
    println!("  Avg active licenses per zip:  {:.1}", finding.avg_active_licenses_per_zip);
    println!("  Std dev active licenses:      {:.1}", finding.std_dev_active_licenses);
    println!("  Top zip ({}) active licenses: {}", finding.top_zip, finding.top_zip_active_licenses);
    println!("  Top zip taverns:              {}", finding.top_zip_taverns);
    println!("  Police % above avg salary:    {:.1}%", finding.police_pct_above_avg);
    println!("  Fire % above avg salary:      {:.1}%", finding.fire_pct_above_avg);
    println!("  Total public safety above avg: {}", finding.overall_above_avg_public_safety);
}