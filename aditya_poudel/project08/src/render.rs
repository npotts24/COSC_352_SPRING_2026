use colored::Colorize;
use comfy_table::{Attribute, Cell, ContentArrangement, Table};
use crate::model::NeighborhoodStats;

pub fn print_banner(title: &str) {
    println!();
    println!("{}", format!(" {} ", title).on_bright_blue().white().bold());
    println!();
}

pub fn print_neighborhood_table(stats: &[NeighborhoodStats]) {
    let mut table = Table::new();
    table.set_content_arrangement(ContentArrangement::Dynamic);
    table.set_header(vec![
        Cell::new("Neighborhood").add_attribute(Attribute::Bold),
        Cell::new("Vacant\nBuildings").add_attribute(Attribute::Bold),
        Cell::new("Arrests").add_attribute(Attribute::Bold),
        Cell::new("Arrests /\nVacant").add_attribute(Attribute::Bold),
    ]);
    for s in stats {
        table.add_row(vec![
            s.neighborhood.clone(),
            s.vacant_count.to_string(),
            s.arrest_count.to_string(),
            format!("{:.2}", s.arrests_per_vacant),
        ]);
    }
    println!("{table}");
}

pub fn print_correlation(r: f64, n: usize) {
    println!();
    println!("{}", "── Pearson Correlation: Vacant Buildings vs Arrests ──".bold().cyan());
    println!();
    println!(
        "  r = {}   (n = {} neighborhoods)",
        format!("{:.4}", r).yellow().bold(), n
    );
    println!();
    println!("  {}", NeighborhoodStats::interpret(r));
    println!();
}

pub fn print_summary_stats(stats: &[NeighborhoodStats]) {
    let total_vacants: usize = stats.iter().map(|s| s.vacant_count).sum();
    let total_arrests: usize = stats.iter().map(|s| s.arrest_count).sum();
    let top = stats.iter().take(5).collect::<Vec<_>>();
    let bottom = stats.iter().rev().take(5).collect::<Vec<_>>();

    println!("{}", "── Summary ──".bold().cyan());
    println!("  Neighborhoods matched : {}", stats.len());
    println!("  Total vacant buildings: {}", total_vacants);
    println!("  Total arrests         : {}", total_arrests);
    println!();

    println!("{}", "── Top 5 neighborhoods by vacancy count ──".bold().cyan());
    print_neighborhood_table(&top.iter().map(|s| NeighborhoodStats {
        neighborhood: s.neighborhood.clone(),
        vacant_count: s.vacant_count,
        arrest_count: s.arrest_count,
        arrests_per_vacant: s.arrests_per_vacant,
    }).collect::<Vec<_>>());

    println!("{}", "── Bottom 5 neighborhoods by vacancy count ──".bold().cyan());
    print_neighborhood_table(&bottom.iter().rev().map(|s| NeighborhoodStats {
        neighborhood: s.neighborhood.clone(),
        vacant_count: s.vacant_count,
        arrest_count: s.arrest_count,
        arrests_per_vacant: s.arrests_per_vacant,
    }).collect::<Vec<_>>());
}