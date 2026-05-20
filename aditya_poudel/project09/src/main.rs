mod loader;
mod charts;

use std::fs;
use colored::Colorize;

use csvprof::error::Result;
use csvprof::profiler::{ProfileOptions, Profiler, CsvSource};
use csvprof::error::ProfileError;

use loader::{load_arrests, load_vacants, join_on_neighborhood};

fn main() {
    if let Err(e) = run() {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let arrests_path = "../project08/data/BPD_Arrests.csv";
    let vacants_path = "../project08/data/Vacant_Building_Notices.csv";
    let out_dir      = "output";

    fs::create_dir_all(out_dir).ok();

    println!("{}", " Step 1 — Loading datasets ".on_bright_blue().white().bold());
    let (arrests, _) = load_arrests(arrests_path)?;
    println!("  Arrests : {}", arrests.len());

    let (vacants, _) = load_vacants(vacants_path)?;
    println!("  Vacants : {}", vacants.len());

    let stats = join_on_neighborhood(&arrests, &vacants);
    println!("  Matched neighborhoods: {}", stats.len());

    println!("\n{}", " Step 2 — Profiling columns (csvprof reuse) ".on_bright_blue().white().bold());
    let arrest_profile = profile_csv(arrests_path)?;
    let vacant_profile = profile_csv(vacants_path)?;
    println!("  Arrest columns : {}", arrest_profile.len());
    println!("  Vacant columns : {}", vacant_profile.len());

    println!("\n{}", " Step 3 — Generating charts ".on_bright_blue().white().bold());

    let p = format!("{}/scatter_vacants_vs_arrests.png", out_dir);
    charts::scatter_vacants_vs_arrests(&stats, &p).unwrap();
    println!("  {} scatter_vacants_vs_arrests.png", "✓".green());

    let p = format!("{}/bar_top_vacancies.png", out_dir);
    charts::bar_top_vacancies(&stats, &p, 15).unwrap();
    println!("  {} bar_top_vacancies.png", "✓".green());

    let p = format!("{}/bar_top_arrests.png", out_dir);
    charts::bar_top_arrests(&stats, &p, 15).unwrap();
    println!("  {} bar_top_arrests.png", "✓".green());

    let p = format!("{}/hist_arrests_per_vacant.png", out_dir);
    charts::hist_ratio(&stats, &p).unwrap();
    println!("  {} hist_arrests_per_vacant.png", "✓".green());

    let p = format!("{}/profile_null_rates.png", out_dir);
    charts::bar_null_rates(&arrest_profile, &vacant_profile, &p).unwrap();
    println!("  {} profile_null_rates.png", "✓".green());

    println!("\n{}", " Done — charts saved to output/ ".on_bright_green().white().bold());
    Ok(())
}

fn profile_csv(path: &str) -> Result<Vec<csvprof::stats::ColumnReport>> {
    use std::fs::File;
    use std::io::BufReader;

    let f = File::open(path)
        .map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
    let mut reader = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_reader(BufReader::new(f));

    let headers: Vec<String> = reader.headers()?
        .iter().map(|s| s.to_string()).collect();

    let options = ProfileOptions {
        percentiles: true,
        histogram: false,
        categorical_threshold: 0.15,
        reservoir_size: 5000,
        ..Default::default()
    };

    let profiler = Profiler::new(options);
    let mut source = CsvSource::new(reader);
    profiler.profile(headers, &mut source)
}