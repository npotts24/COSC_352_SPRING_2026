use std::borrow::Cow;
use std::collections::HashMap;
use std::fs::File;
use std::io::{self, BufReader, Cursor, Write};
use std::path::{Path, PathBuf};

use anyhow::Context;
use clap::Parser;
use csv::{Reader, ReaderBuilder, StringRecord, WriterBuilder};

use csvprof::cli::DEFAULT_NULLS;
use csvprof::profiler::{Profiler, ProfilerConfig};
use csvprof::report;
use csvprof::types::OutputFormat;

#[derive(Debug, Parser)]
#[command(
    name = "csvjoin",
    version,
    about = "Join Baltimore crime and vacant-building CSVs by neighborhood"
)]
struct Cli {
    /// NIBRS Group A Crime Data CSV.
    #[arg(long)]
    crime: PathBuf,
    /// Vacant Building Notices CSV.
    #[arg(long)]
    vacant: PathBuf,
    /// Write joined CSV here. Defaults to stdout.
    #[arg(short, long)]
    output: Option<PathBuf>,
    /// Key column in the crime CSV.
    #[arg(long, default_value = "Neighborhood")]
    crime_key: String,
    /// Key column in the vacant-building CSV.
    #[arg(long, default_value = "Neighborhood")]
    vacant_key: String,
    /// Incident-count column in the crime CSV.
    #[arg(long, default_value = "Total_Incidents")]
    incident_column: String,
    /// Crime-description column used for violent-crime rollups.
    #[arg(long, default_value = "Description")]
    crime_type_column: String,
    /// Shooting marker column in the crime CSV.
    #[arg(long, default_value = "Shooting")]
    shooting_column: String,
    /// Cancel date column in the vacant-building CSV.
    #[arg(long, default_value = "DateCancel")]
    vacant_cancel_column: String,
    /// Abatement date column in the vacant-building CSV.
    #[arg(long, default_value = "DateAbate")]
    vacant_abate_column: String,
    /// Also write a csvprof markdown profile for the joined CSV.
    #[arg(long)]
    joined_profile: Option<PathBuf>,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let joined = correlate(&cli)?;
    let joined_csv = render_joined_csv(&joined.rows)?;

    match &cli.output {
        Some(path) => std::fs::write(path, &joined_csv)
            .with_context(|| format!("failed to write `{}`", path.display()))?,
        None => io::stdout()
            .write_all(&joined_csv)
            .context("failed to write joined CSV to stdout")?,
    }

    if let Some(path) = &cli.joined_profile {
        write_joined_profile(path, &joined_csv)?;
    }

    eprintln!("{}", joined.summary);
    Ok(())
}

#[derive(Debug)]
struct JoinResult {
    rows: Vec<NeighborhoodRow>,
    summary: JoinSummary,
}

#[derive(Debug, Clone, Default)]
struct NeighborhoodRow {
    neighborhood: String,
    crime_events: u64,
    crime_total_incidents: u64,
    violent_events: u64,
    shooting_events: u64,
    vacant_notices: u64,
    active_vacant_notices: u64,
    closed_or_abated_vacant_notices: u64,
}

impl NeighborhoodRow {
    fn crime_events_per_active_vacant_notice(&self) -> Option<f64> {
        (self.active_vacant_notices > 0)
            .then(|| self.crime_events as f64 / self.active_vacant_notices as f64)
    }
}

#[derive(Debug, Default)]
struct JoinCounters {
    vacant_rows: u64,
    crime_rows: u64,
    skipped_vacant_rows: u64,
    skipped_crime_rows: u64,
}

#[derive(Debug)]
struct JoinSummary {
    neighborhoods: usize,
    vacant_rows: u64,
    crime_rows: u64,
    skipped_vacant_rows: u64,
    skipped_crime_rows: u64,
    pearson_correlation: Option<f64>,
    high_vacancy_mean_crimes: Option<f64>,
    low_vacancy_mean_crimes: Option<f64>,
    high_low_ratio: Option<f64>,
}

impl std::fmt::Display for JoinSummary {
    fn fmt(&self, output: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        writeln!(output, "csvjoin summary")?;
        writeln!(output, "  neighborhoods joined: {}", self.neighborhoods)?;
        writeln!(
            output,
            "  rows read: {} crime, {} vacant-building",
            self.crime_rows, self.vacant_rows
        )?;
        writeln!(
            output,
            "  rows skipped for missing/invalid keys: {} crime, {} vacant-building",
            self.skipped_crime_rows, self.skipped_vacant_rows
        )?;
        writeln!(
            output,
            "  Pearson(active vacancies, crime events): {}",
            render_optional_f64(self.pearson_correlation)
        )?;
        writeln!(
            output,
            "  mean crime events in top vacancy quartile: {}",
            render_optional_f64(self.high_vacancy_mean_crimes)
        )?;
        writeln!(
            output,
            "  mean crime events in bottom vacancy quartile: {}",
            render_optional_f64(self.low_vacancy_mean_crimes)
        )?;
        write!(
            output,
            "  top/bottom vacancy quartile crime ratio: {}",
            render_optional_f64(self.high_low_ratio)
        )
    }
}

fn correlate(cli: &Cli) -> anyhow::Result<JoinResult> {
    let mut rows = HashMap::<String, NeighborhoodRow>::new();
    let mut counters = JoinCounters::default();

    // The join is intentionally asymmetric. Vacant Building Notices is the
    // small side, so we hash-aggregate it by normalized neighborhood first.
    // Then the larger crime file is streamed once and accumulated into the
    // same per-neighborhood entries. Memory grows with neighborhood count, not
    // with input row count, and the output avoids a many-to-many row explosion.
    read_vacant_buildings(cli, &mut rows, &mut counters)?;
    read_crimes(cli, &mut rows, &mut counters)?;

    let mut rows: Vec<_> = rows.into_values().collect();
    rows.sort_by(|left, right| {
        right
            .active_vacant_notices
            .cmp(&left.active_vacant_notices)
            .then_with(|| right.crime_events.cmp(&left.crime_events))
            .then_with(|| left.neighborhood.cmp(&right.neighborhood))
    });

    let summary = summarize(&rows, counters);
    Ok(JoinResult { rows, summary })
}

fn read_vacant_buildings(
    cli: &Cli,
    rows: &mut HashMap<String, NeighborhoodRow>,
    counters: &mut JoinCounters,
) -> anyhow::Result<()> {
    let mut reader = open_csv(&cli.vacant)?;
    let headers = reader
        .headers()
        .context("failed to read vacant-building headers")?
        .clone();
    let key_index = required_column(&headers, &cli.vacant_key)?;
    let cancel_index = optional_column(&headers, &cli.vacant_cancel_column);
    let abate_index = optional_column(&headers, &cli.vacant_abate_column);

    for record in reader.records() {
        let record = record.context("failed to read vacant-building record")?;
        counters.vacant_rows += 1;

        let Some((key, display)) = normalized_record_key(&record, key_index) else {
            counters.skipped_vacant_rows += 1;
            continue;
        };

        let entry = rows
            .entry(key.into_owned())
            .or_insert_with(|| NeighborhoodRow {
                neighborhood: display.into_owned(),
                ..NeighborhoodRow::default()
            });
        entry.vacant_notices += 1;

        let closed_or_abated =
            has_value(record.get_opt(cancel_index)) || has_value(record.get_opt(abate_index));
        if closed_or_abated {
            entry.closed_or_abated_vacant_notices += 1;
        } else {
            entry.active_vacant_notices += 1;
        }
    }

    Ok(())
}

fn read_crimes(
    cli: &Cli,
    rows: &mut HashMap<String, NeighborhoodRow>,
    counters: &mut JoinCounters,
) -> anyhow::Result<()> {
    let mut reader = open_csv(&cli.crime)?;
    let headers = reader
        .headers()
        .context("failed to read crime headers")?
        .clone();
    let key_index = required_column(&headers, &cli.crime_key)?;
    let incident_index = optional_column(&headers, &cli.incident_column);
    let type_index = optional_column(&headers, &cli.crime_type_column);
    let shooting_index = optional_column(&headers, &cli.shooting_column);

    for record in reader.records() {
        let record = record.context("failed to read crime record")?;
        counters.crime_rows += 1;

        let Some((key, display)) = normalized_record_key(&record, key_index) else {
            counters.skipped_crime_rows += 1;
            continue;
        };

        let total_incidents = record
            .get_opt(incident_index)
            .and_then(parse_u64_cell)
            .unwrap_or(1);
        let is_violent = record
            .get_opt(type_index)
            .map(is_violent_crime)
            .unwrap_or(false);
        let is_shooting = record
            .get_opt(shooting_index)
            .map(is_truthy)
            .unwrap_or(false);

        let entry = rows
            .entry(key.into_owned())
            .or_insert_with(|| NeighborhoodRow {
                neighborhood: display.into_owned(),
                ..NeighborhoodRow::default()
            });
        entry.crime_events += 1;
        entry.crime_total_incidents += total_incidents;
        if is_violent {
            entry.violent_events += 1;
        }
        if is_shooting {
            entry.shooting_events += 1;
        }
    }

    Ok(())
}

fn open_csv(path: &Path) -> anyhow::Result<Reader<BufReader<File>>> {
    let file = File::open(path).with_context(|| format!("failed to open `{}`", path.display()))?;
    Ok(ReaderBuilder::new()
        .flexible(true)
        .trim(csv::Trim::All)
        .from_reader(BufReader::new(file)))
}

fn render_joined_csv(rows: &[NeighborhoodRow]) -> anyhow::Result<Vec<u8>> {
    let mut writer = WriterBuilder::new().from_writer(Vec::new());
    writer.write_record([
        "neighborhood",
        "crime_events",
        "crime_total_incidents",
        "violent_events",
        "shooting_events",
        "vacant_notices",
        "active_vacant_notices",
        "closed_or_abated_vacant_notices",
        "crime_events_per_active_vacant_notice",
    ])?;

    for row in rows {
        let per_vacant = row
            .crime_events_per_active_vacant_notice()
            .map(|value| format!("{value:.6}"))
            .unwrap_or_default();
        writer.write_record([
            row.neighborhood.as_str(),
            &row.crime_events.to_string(),
            &row.crime_total_incidents.to_string(),
            &row.violent_events.to_string(),
            &row.shooting_events.to_string(),
            &row.vacant_notices.to_string(),
            &row.active_vacant_notices.to_string(),
            &row.closed_or_abated_vacant_notices.to_string(),
            &per_vacant,
        ])?;
    }

    writer
        .into_inner()
        .context("failed to flush joined CSV writer")
}

fn write_joined_profile(path: &Path, joined_csv: &[u8]) -> anyhow::Result<()> {
    let mut profiler = Profiler::new(joined_profile_config());
    profiler
        .profile_reader(Cursor::new(joined_csv))
        .context("failed to profile joined CSV")?;
    let rendered = report::render(&profiler.finalize(), OutputFormat::Markdown)?;
    std::fs::write(path, rendered)
        .with_context(|| format!("failed to write joined profile `{}`", path.display()))
}

fn joined_profile_config() -> ProfilerConfig {
    ProfilerConfig {
        delimiter: b',',
        has_headers: true,
        top_k: 5,
        top_k_capacity: 32,
        distinct_capacity: 1024,
        sample_size: 4096,
        percentiles: vec![25.0, 75.0, 90.0],
        null_values: DEFAULT_NULLS
            .iter()
            .map(|value| value.to_string())
            .collect(),
    }
}

fn required_column(headers: &StringRecord, expected: &str) -> anyhow::Result<usize> {
    optional_column(headers, expected).with_context(|| {
        let available = headers
            .iter()
            .map(clean_header)
            .collect::<Vec<_>>()
            .join(", ");
        format!("missing required column `{expected}`; available columns: {available}")
    })
}

fn optional_column(headers: &StringRecord, expected: &str) -> Option<usize> {
    headers
        .iter()
        .position(|header| clean_header(header).eq_ignore_ascii_case(expected))
}

fn clean_header(header: &str) -> &str {
    header.trim_start_matches('\u{feff}').trim()
}

trait OptionalRecordGet {
    fn get_opt(&self, index: Option<usize>) -> Option<&str>;
}

impl OptionalRecordGet for StringRecord {
    fn get_opt(&self, index: Option<usize>) -> Option<&str> {
        index.and_then(|index| self.get(index))
    }
}

fn normalized_record_key(
    record: &StringRecord,
    key_index: usize,
) -> Option<(Cow<'_, str>, Cow<'_, str>)> {
    let raw = record.get(key_index)?;
    let display = clean_value(raw)?;
    let key = normalized_key(display)?;
    Some((key, Cow::Borrowed(display)))
}

fn clean_value(raw: &str) -> Option<&str> {
    let value = raw.trim_start_matches('\u{feff}').trim();
    (!is_missing_key(value)).then_some(value)
}

fn normalized_key(raw: &str) -> Option<Cow<'_, str>> {
    let value = clean_value(raw)?;
    let already_normalized = !value.bytes().any(|byte| byte.is_ascii_lowercase())
        && !value.split_whitespace().any(|part| part.is_empty())
        && !value.contains("  ");
    if already_normalized {
        return Some(Cow::Borrowed(value));
    }

    Some(Cow::Owned(
        value
            .split_whitespace()
            .map(str::to_ascii_uppercase)
            .collect::<Vec<_>>()
            .join(" "),
    ))
}

fn is_missing_key(value: &str) -> bool {
    let normalized = value.trim().to_ascii_uppercase();
    matches!(
        normalized.as_str(),
        "" | "N/A" | "NA" | "NONE" | "NULL" | "UNKNOWN"
    )
}

fn has_value(value: Option<&str>) -> bool {
    value.map(str::trim).is_some_and(|value| !value.is_empty())
}

fn parse_u64_cell(value: &str) -> Option<u64> {
    let trimmed = value.trim();
    trimmed.parse::<u64>().ok().or_else(|| {
        trimmed
            .parse::<f64>()
            .ok()
            .map(|value| value.round() as u64)
    })
}

fn is_violent_crime(description: &str) -> bool {
    let description = description.to_ascii_uppercase();
    ["HOMICIDE", "ROBBERY", "ASSAULT", "RAPE", "SHOOTING"]
        .iter()
        .any(|needle| description.contains(needle))
}

fn is_truthy(value: &str) -> bool {
    matches!(
        value.trim().to_ascii_uppercase().as_str(),
        "Y" | "YES" | "TRUE" | "T" | "1"
    )
}

fn summarize(rows: &[NeighborhoodRow], counters: JoinCounters) -> JoinSummary {
    let pearson_correlation = pearson(
        rows.iter()
            .map(|row| (row.active_vacant_notices as f64, row.crime_events as f64)),
    );

    let quartile_size = ((rows.len() as f64) * 0.25).ceil() as usize;
    let quartile_size = quartile_size.max(1).min(rows.len().max(1));
    let high_vacancy = &rows[..quartile_size.min(rows.len())];
    let low_start = rows.len().saturating_sub(quartile_size);
    let low_vacancy = &rows[low_start..];

    let high_vacancy_mean_crimes = mean_crimes(high_vacancy);
    let low_vacancy_mean_crimes = mean_crimes(low_vacancy);
    let high_low_ratio = match (high_vacancy_mean_crimes, low_vacancy_mean_crimes) {
        (Some(high), Some(low)) if low > 0.0 => Some(high / low),
        _ => None,
    };

    JoinSummary {
        neighborhoods: rows.len(),
        vacant_rows: counters.vacant_rows,
        crime_rows: counters.crime_rows,
        skipped_vacant_rows: counters.skipped_vacant_rows,
        skipped_crime_rows: counters.skipped_crime_rows,
        pearson_correlation,
        high_vacancy_mean_crimes,
        low_vacancy_mean_crimes,
        high_low_ratio,
    }
}

fn mean_crimes(rows: &[NeighborhoodRow]) -> Option<f64> {
    (!rows.is_empty())
        .then(|| rows.iter().map(|row| row.crime_events as f64).sum::<f64>() / rows.len() as f64)
}

fn pearson<I>(pairs: I) -> Option<f64>
where
    I: IntoIterator<Item = (f64, f64)>,
{
    let pairs: Vec<_> = pairs.into_iter().collect();
    if pairs.len() < 2 {
        return None;
    }

    let count = pairs.len() as f64;
    let mean_x = pairs.iter().map(|(x, _)| x).sum::<f64>() / count;
    let mean_y = pairs.iter().map(|(_, y)| y).sum::<f64>() / count;

    let mut numerator = 0.0;
    let mut variance_x = 0.0;
    let mut variance_y = 0.0;
    for (x, y) in pairs {
        let dx = x - mean_x;
        let dy = y - mean_y;
        numerator += dx * dy;
        variance_x += dx * dx;
        variance_y += dy * dy;
    }

    let denominator = variance_x.sqrt() * variance_y.sqrt();
    (denominator > 0.0).then(|| numerator / denominator)
}

fn render_optional_f64(value: Option<f64>) -> String {
    value
        .map(|value| format!("{value:.3}"))
        .unwrap_or_else(|| "n/a".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_neighborhood_keys_without_allocating_when_possible() {
        assert!(matches!(
            normalized_key("CANTON"),
            Some(Cow::Borrowed("CANTON"))
        ));
        assert_eq!(
            normalized_key(" Carrollton Ridge ").map(Cow::into_owned),
            Some("CARROLLTON RIDGE".to_string())
        );
    }

    #[test]
    fn rejects_placeholder_keys() {
        assert!(normalized_key("N/A").is_none());
        assert!(normalized_key("").is_none());
    }

    #[test]
    fn computes_positive_correlation() {
        let corr = pearson([(1.0, 2.0), (2.0, 4.0), (3.0, 9.0)]).unwrap();
        assert!(corr > 0.95);
    }
}
