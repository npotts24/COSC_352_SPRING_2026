use anyhow::{Context, Result};
use csv::ReaderBuilder;
use plotters::prelude::*;
use serde::Deserialize;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

#[derive(Debug)]
struct NeighborhoodStat {
    name: String,
    vacant_lots: f64,
    requests: f64,
}

#[derive(Debug, Deserialize)]
struct ProfileMetric {
    dataset: String,
    metric: String,
    value: f64,
}

fn main() -> Result<()> {
    let project08_data = Path::new("../project08/data");
    let local_metrics = Path::new("data/profile_metrics.csv");
    let output_dir = Path::new("output");

    fs::create_dir_all(output_dir)?;

    let vacant_path = project08_data.join("vacant_lots_per_neighborhood.csv");
    let request_path = project08_data.join("311_requests_2024.csv");

    let vacant_map = load_vacant_lots(&vacant_path)
        .with_context(|| format!("Failed to load vacant lot data from {}", vacant_path.display()))?;
    let request_map = load_311_counts(&request_path)
        .with_context(|| format!("Failed to load 311 request data from {}", request_path.display()))?;

    let joined = join_neighborhoods(&vacant_map, &request_map);
    let correlation = compute_correlation(&joined);

    let profile_metrics = load_profile_metrics(local_metrics)
        .with_context(|| format!("Failed to load profile metrics from {}", local_metrics.display()))?;

    println!("Project 09: Plotters Visualization");
    println!("Neighborhoods joined: {}", joined.len());
    println!("Correlation (vacant lots vs 311 requests): {:.4}", correlation);
    println!("Generated plots in {}", output_dir.display());

    draw_vacant_vs_requests(&output_dir.join("vacant_vs_requests.png"), &joined)?;
    draw_top_neighborhood_requests(&output_dir.join("top_neighborhood_requests.png"), &joined)?;
    draw_profile_metrics(&output_dir.join("profile_metrics.png"), &profile_metrics)?;

    Ok(())
}

fn normalize_name(name: &str) -> String {
    name.to_lowercase()
        .chars()
        .filter(|c| c.is_alphanumeric())
        .collect()
}

fn load_vacant_lots(path: &Path) -> Result<HashMap<String, (String, f64)>> {
    let mut reader = ReaderBuilder::new().has_headers(true).from_path(path)?;
    let mut map = HashMap::new();

    for result in reader.records() {
        let record = result?;
        let name = record.get(4).unwrap_or("").trim().to_string();
        let value = record
            .get(0)
            .unwrap_or("0")
            .parse::<f64>()
            .unwrap_or(0.0);
        if !name.is_empty() {
            map.insert(normalize_name(&name), (name, value));
        }
    }

    Ok(map)
}

fn load_311_counts(path: &Path) -> Result<HashMap<String, f64>> {
    let mut reader = ReaderBuilder::new().has_headers(true).from_path(path)?;
    let mut map = HashMap::new();

    for result in reader.records() {
        let record = result?;
        let name = record.get(17).unwrap_or("").trim();
        if name.is_empty() {
            continue;
        }
        *map.entry(normalize_name(name)).or_insert(0.0) += 1.0;
    }

    Ok(map)
}

fn join_neighborhoods(
    vacant: &HashMap<String, (String, f64)>,
    requests: &HashMap<String, f64>,
) -> Vec<NeighborhoodStat> {
    let mut joined = Vec::new();

    for (normalized, (name, vacant_lots)) in vacant {
        let request_count = *requests.get(normalized).unwrap_or(&0.0);
        joined.push(NeighborhoodStat {
            name: name.clone(),
            vacant_lots: *vacant_lots,
            requests: request_count,
        });
    }

    joined.sort_by(|a, b| b.requests.partial_cmp(&a.requests).unwrap());
    joined
}

fn compute_correlation(data: &[NeighborhoodStat]) -> f64 {
    let n = data.len() as f64;
    if n < 2.0 {
        return 0.0;
    }

    let sum_x: f64 = data.iter().map(|row| row.vacant_lots).sum();
    let sum_y: f64 = data.iter().map(|row| row.requests).sum();
    let sum_xy: f64 = data.iter().map(|row| row.vacant_lots * row.requests).sum();
    let sum_x2: f64 = data.iter().map(|row| row.vacant_lots.powi(2)).sum();
    let sum_y2: f64 = data.iter().map(|row| row.requests.powi(2)).sum();

    let numerator = n * sum_xy - sum_x * sum_y;
    let denominator = ((n * sum_x2 - sum_x.powi(2)) * (n * sum_y2 - sum_y.powi(2))).sqrt();
    if denominator == 0.0 {
        0.0
    } else {
        numerator / denominator
    }
}

fn load_profile_metrics(path: &Path) -> Result<Vec<ProfileMetric>> {
    let mut reader = ReaderBuilder::new().has_headers(true).from_path(path)?;
    let mut metrics = Vec::new();

    for result in reader.deserialize() {
        metrics.push(result?);
    }

    Ok(metrics)
}

fn draw_vacant_vs_requests(path: &Path, joined: &[NeighborhoodStat]) -> Result<()> {
    let root = BitMapBackend::new(path, (1200, 800)).into_drawing_area();
    root.fill(&WHITE)?;

    let max_vacant = joined.iter().map(|row| row.vacant_lots).fold(0.0, f64::max);
    let max_requests = joined.iter().map(|row| row.requests).fold(0.0, f64::max);

    let mut chart = ChartBuilder::on(&root)
        .caption("Vacant Lots vs 311 Requests", ("sans-serif", 28).into_font())
        .margin(30)
        .x_label_area_size(50)
        .y_label_area_size(80)
        .build_cartesian_2d(0.0..(max_vacant * 1.1 + 1.0), 0.0..(max_requests * 1.1 + 50.0))?;

    chart
        .configure_mesh()
        .x_desc("Vacant Lots")
        .y_desc("311 Requests")
        .disable_mesh()
        .draw()?;

    chart.draw_series(
        joined.iter().map(|row| Circle::new(
            (row.vacant_lots, row.requests),
            4,
            RGBAColor(0, 100, 200, 0.7).filled(),
        )),
    )?;

    Ok(())
}

fn draw_top_neighborhood_requests(path: &Path, joined: &[NeighborhoodStat]) -> Result<()> {
    let root = BitMapBackend::new(path, (1400, 900)).into_drawing_area();
    root.fill(&WHITE)?;

    let top: Vec<_> = joined.iter().take(10).collect();
    let max_requests = top.iter().map(|row| row.requests).fold(0.0, f64::max);

    let mut chart = ChartBuilder::on(&root)
        .caption("Top 10 Neighborhoods by 311 Requests", ("sans-serif", 28).into_font())
        .margin(30)
        .x_label_area_size(120)
        .y_label_area_size(80)
        .build_cartesian_2d(0..top.len(), 0.0..(max_requests * 1.2 + 50.0))?;

    chart
        .configure_mesh()
        .x_labels(top.len())
        .x_label_formatter(&|idx| {
            top.get(*idx)
                .map(|row| row.name.clone())
                .unwrap_or_else(|| "".to_string())
        })
        .x_desc("Neighborhood")
        .y_desc("311 Requests")
        .label_style(("sans-serif", 14))
        .draw()?;

    for (idx, row) in top.iter().enumerate() {
        chart.draw_series(std::iter::once(Rectangle::new(
            [(idx, 0.0), (idx + 1, row.requests)],
            RGBColor(30, 144, 255).filled(),
        )))?;
    }

    Ok(())
}

fn draw_profile_metrics(path: &Path, metrics: &[ProfileMetric]) -> Result<()> {
    let root = BitMapBackend::new(path, (1100, 700)).into_drawing_area();
    root.fill(&WHITE)?;

    let labels: Vec<String> = metrics
        .iter()
        .map(|metric| format!("{}: {}", metric.dataset, metric.metric))
        .collect();
    let max_value = metrics.iter().map(|metric| metric.value.abs()).fold(0.0, f64::max);

    let mut chart = ChartBuilder::on(&root)
        .caption("Profile Metrics and Correlation", ("sans-serif", 28).into_font())
        .margin(30)
        .x_label_area_size(150)
        .y_label_area_size(80)
        .build_cartesian_2d(0..metrics.len(), -(max_value * 1.2 + 1.0)..(max_value * 1.2 + 1.0))?;

    chart
        .configure_mesh()
        .x_labels(metrics.len())
        .x_label_formatter(&|idx| labels.get(*idx).cloned().unwrap_or_default())
        .x_desc("Metric")
        .y_desc("Value")
        .label_style(("sans-serif", 14))
        .draw()?;

    for (idx, metric) in metrics.iter().enumerate() {
        let color = if metric.value < 0.0 {
            RGBColor(220, 50, 50)
        } else {
            RGBColor(0, 102, 204)
        };
        chart.draw_series(std::iter::once(Rectangle::new(
            [(idx, 0.0), (idx + 1, metric.value)],
            color.filled(),
        )))?;
    }

    Ok(())
}
