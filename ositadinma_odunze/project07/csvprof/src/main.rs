//! csvprof — streaming CSV data-profiling CLI
//!
//! Entry point: parse args → open reader → run profiler → render report.

mod accumulator;
mod cli;
mod error;
mod infer;
mod profiler;
mod report;
mod types;

use std::{
    fs::File,
    io::{self, BufReader},
};

use anyhow::{Context, Result};
use clap::Parser;

use crate::{
    accumulator::AccumulatorConfig,
    cli::Cli,
};

fn main() {
    if let Err(e) = run() {
        eprintln!("{}: {}", colored::Colorize::red("error"), e);
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();

    let cfg = AccumulatorConfig {
        categorical_threshold: cli.categorical_threshold,
        max_categories:        cli.max_categories,
        compute_percentiles:   cli.percentiles,
        emit_histogram:        cli.histogram,
    };

    // Validate and convert delimiter
    let delim_byte = {
        let s = cli.delimiter.to_string();
        if s.len() != 1 {
            anyhow::bail!("Delimiter must be a single ASCII character");
        }
        s.as_bytes()[0]
    };

    // ── choose reader: file vs stdin ─────────────────────────────────────
    let profile = if cli.file == "-" {
        let stdin = io::stdin();
        let rdr = csv::ReaderBuilder::new()
            .delimiter(delim_byte)
            .has_headers(true)
            .flexible(true)
            .trim(csv::Trim::All)
            .from_reader(stdin.lock());
        run_with_csv_reader(rdr, "<stdin>", cfg)?
    } else {
        // Validate the path exists before attempting
        if !std::path::Path::new(&cli.file).exists() {
            anyhow::bail!("File not found: {}", cli.file);
        }
        let file = File::open(&cli.file)
            .with_context(|| format!("Cannot open '{}'", cli.file))?;
        let rdr = csv::ReaderBuilder::new()
            .delimiter(delim_byte)
            .has_headers(true)
            .flexible(true)
            .trim(csv::Trim::All)
            .from_reader(BufReader::new(file));
        run_with_csv_reader(rdr, &cli.file, cfg)?
    };

    // ── render ────────────────────────────────────────────────────────────
    if cli.json {
        println!("{}", serde_json::to_string_pretty(&profile)?);
    } else {
        report::print_report(&profile, cli.percentiles, cli.histogram);
    }

    Ok(())
}

/// Generic helper so we don't duplicate logic for file vs stdin.
fn run_with_csv_reader<R: io::Read>(
    mut rdr: csv::Reader<R>,
    label: &str,
    cfg: AccumulatorConfig,
) -> Result<types::FileProfile> {
    use crate::accumulator::ColumnAccumulator;

    let headers: Vec<String> = {
        let h = rdr.headers().context("Failed to read CSV headers")?;
        if h.is_empty() {
            anyhow::bail!("No columns found in CSV file");
        }
        h.iter().map(str::to_owned).collect()
    };

    let ncols = headers.len();
    let mut accumulators: Vec<ColumnAccumulator> = headers
        .iter()
        .map(|h| ColumnAccumulator::new(h, cfg.max_categories))
        .collect();

    let mut total_rows: u64 = 0;
    let mut record = csv::StringRecord::new();

    while rdr.read_record(&mut record).context("CSV read error")? {
        total_rows += 1;
        for (i, acc) in accumulators.iter_mut().enumerate() {
            let value = record.get(i).and_then(|s| {
                let t = s.trim();
                if t.is_empty() { None } else { Some(t) }
            });
            acc.feed(value);
        }
    }

    let columns = accumulators
        .into_iter()
        .map(|acc| acc.finalize(&cfg))
        .collect();

    Ok(types::FileProfile {
        file: label.to_owned(),
        total_rows,
        total_cols: ncols,
        columns,
    })
}
