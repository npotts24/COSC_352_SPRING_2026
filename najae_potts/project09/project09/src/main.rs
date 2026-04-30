use anyhow::Result;
use csv::StringRecord;
use plotters::prelude::*;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

fn main() -> Result<()> {
    fs::create_dir_all("output")?;

    let liquor_path = "../../project08/data/Liquor_Licenses.csv";
    let vacant_path = "../../project08/data/Vacant_Building_Rehabs.csv";

    let liquor = read_liquor(liquor_path)?;
    let vacants = read_vacants(vacant_path)?;

    plot_license_fee_scatter(&liquor, "output/license_fee_scatter.png")?;
    plot_license_year_counts(&liquor, "output/license_year_counts.png")?;
    plot_vacants_by_district(&vacants, "output/vacants_by_district.png")?;

    println!("Plots written to output/");
    Ok(())
}

#[derive(Debug)]
struct LiquorRow {
    year: i32,
    fee: f64,
}

fn read_liquor<P: AsRef<Path>>(path: P) -> Result<Vec<LiquorRow>> {
    let mut rdr = csv::Reader::from_path(path)?;
    let headers = rdr.headers()?.clone();

    let year_idx = headers.iter().position(|h| h == "LicenseYear").unwrap_or(0);
    let fee_idx = headers.iter().position(|h| h == "LicenseFee").unwrap_or(0);

    let mut out = Vec::new();

    for result in rdr.records() {
        let record = result?;
        if let Some(row) = parse_liquor_record(&record, year_idx, fee_idx) {
            out.push(row);
        }
    }
    Ok(out)
}

fn parse_liquor_record(rec: &StringRecord, year_idx: usize, fee_idx: usize) -> Option<LiquorRow> {
    let year = rec.get(year_idx)?.trim().parse::<i32>().ok()?;
    let fee = rec.get(fee_idx)?.trim().parse::<f64>().ok()?;
    Some(LiquorRow { year, fee })
}

#[derive(Debug)]
struct VacantRow {
    year: i32,
    council_district: String,
}

fn read_vacants<P: AsRef<Path>>(path: P) -> Result<Vec<VacantRow>> {
    let mut rdr = csv::Reader::from_path(path)?;
    let headers = rdr.headers()?.clone();

    let date_idx = headers.iter().position(|h| h == "DateIssue").unwrap_or(0);
    let council_idx = headers.iter().position(|h| h == "Council_District").unwrap_or(0);

    let mut out = Vec::new();
    for result in rdr.records() {
        let record = result?;
        if let Some(row) = parse_vacant_record(&record, date_idx, council_idx) {
            out.push(row);
        }
    }
    Ok(out)
}

fn parse_vacant_record(rec: &StringRecord, date_idx: usize, council_idx: usize) -> Option<VacantRow> {
    let date_str = rec.get(date_idx)?.trim();
    // Date samples look like "2025/12/22 00:00:00+00"; take first 4 chars as year when possible
    let year = date_str.get(0..4)?.parse::<i32>().ok()?;
    let council = rec.get(council_idx)?.trim().to_string();
    Some(VacantRow { year, council_district: council })
}

fn plot_license_fee_scatter(data: &[LiquorRow], out: &str) -> Result<()> {
    if data.is_empty() {
        return Ok(());
    }

    let fees: Vec<f64> = data.iter().map(|r| r.fee).collect();
    let years: Vec<i32> = data.iter().map(|r| r.year).collect();

    let min_fee = fees.iter().cloned().fold(f64::INFINITY, f64::min);
    let max_fee = fees.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let min_year = *years.iter().min().unwrap() as i32;
    let max_year = *years.iter().max().unwrap() as i32;

    let root = BitMapBackend::new(out, (1200, 800)).into_drawing_area();
    root.fill(&WHITE)?;

    let mut chart = ChartBuilder::on(&root)
        .caption("License Fee vs Year (scatter)", ("sans-serif", 20).into_font())
        .margin(20)
        .x_label_area_size(40)
        .y_label_area_size(80)
        .build_cartesian_2d(min_year..max_year, (min_fee * 0.9)..(max_fee * 1.1))?;

    chart.configure_mesh().x_desc("Year").y_desc("License Fee").draw()?;

    chart.draw_series(
        data.iter().map(|r| Circle::new((r.year, r.fee), 3, BLUE.filled())),
    )?;

    Ok(())
}

fn plot_license_year_counts(data: &[LiquorRow], out: &str) -> Result<()> {
    let mut counts: HashMap<i32, usize> = HashMap::new();
    for r in data {
        *counts.entry(r.year).or_default() += 1;
    }
    if counts.is_empty() {
        return Ok(());
    }

    let mut pairs: Vec<(i32, usize)> = counts.into_iter().collect();
    pairs.sort_by_key(|p| p.0);

    let min_year = pairs.first().unwrap().0;
    let max_year = pairs.last().unwrap().0;
    let max_count = pairs.iter().map(|p| p.1).max().unwrap();

    let root = BitMapBackend::new(out, (1000, 600)).into_drawing_area();
    root.fill(&WHITE)?;

    let mut chart = ChartBuilder::on(&root)
        .caption("Licenses per Year", ("sans-serif", 20).into_font())
        .margin(10)
        .x_label_area_size(40)
        .y_label_area_size(50)
        .build_cartesian_2d(min_year..max_year, 0usize..(max_count + 5))?;

    chart.configure_mesh().x_desc("Year").y_desc("Count").draw()?;

    chart.draw_series(pairs.iter().map(|(y, c)| {
        let x0 = *y;
        let x1 = *y + 0; // single-year bar
        Rectangle::new([(x0, 0usize), (x0 + 0, *c)], RED.filled())
    }))?;

    // Alternative: draw as line
    chart.draw_series(LineSeries::new(
        pairs.iter().map(|(y, c)| (*y, *c)),
        &BLUE,
    ))?;

    Ok(())
}

fn plot_vacants_by_district(data: &[VacantRow], out: &str) -> Result<()> {
    let mut counts: HashMap<String, usize> = HashMap::new();
    for r in data {
        *counts.entry(r.council_district.clone()).or_default() += 1;
    }
    if counts.is_empty() {
        return Ok(());
    }

    let mut pairs: Vec<(String, usize)> = counts.into_iter().collect();
    pairs.sort_by(|a, b| b.1.cmp(&a.1));

    let categories: Vec<String> = pairs.iter().map(|(k, _)| k.clone()).collect();
    let values: Vec<usize> = pairs.iter().map(|(_, v)| *v).collect();
    let max_val = *values.iter().max().unwrap();

    let root = BitMapBackend::new(out, (1200, 600)).into_drawing_area();
    root.fill(&WHITE)?;

    let mut chart = ChartBuilder::on(&root)
        .caption("Vacant Rehabs by Council District", ("sans-serif", 20).into_font())
        .margin(10)
        .x_label_area_size(40)
        .y_label_area_size(80)
        .build_cartesian_2d(0usize..categories.len(), 0usize..(max_val + 5))?;

    chart.configure_mesh().disable_mesh().x_labels(categories.len()).y_desc("Count").draw()?;

    chart.draw_series(values.iter().enumerate().map(|(i, v)| {
        let x0 = i;
        let x1 = i + 1;
        Rectangle::new([(x0, 0usize), (x1, *v)], GREEN.filled())
    }))?;

    // draw labels under bars
    for (i, cat) in categories.iter().enumerate() {
        let x = i * 1 + 0;
        root.draw(&Text::new(
            cat.clone(),
            ((x + 0) as i32 * 20 + 40, 560),
            ("sans-serif", 14).into_font(),
        ))?;
    }

    Ok(())
}
