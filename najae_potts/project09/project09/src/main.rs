use anyhow::Result;
use csv::StringRecord;
use plotters::prelude::*;
use std::collections::HashMap;
use std::fs;
use std::path::Path;

fn main() -> Result<()> {
    fs::create_dir_all("output")?;
    fs::create_dir_all("reports")?;

    let liquor_path = "../../project08/data/Liquor_Licenses.csv";
    let vacant_path = "../../project08/data/Vacant_Building_Rehabs.csv";

    // raw row data used by some visualizations
    let liquor = read_liquor(liquor_path)?;
    let vacants = read_vacants(vacant_path)?;

    // profiles (category counts) matching project08 behavior
    let liquor_by_zip = profile_liquor_by_zip(liquor_path)?;
    let vacants_by_neighborhood = profile_vacants_by_neighborhood(vacant_path)?;

    // write JSON profiles
    write_json_profile(&liquor_by_zip, "reports/Liquor_Licenses_profile.json")?;
    write_json_profile(&vacants_by_neighborhood, "reports/Vacant_Building_Rehabs_profile.json")?;

    // plots
    plot_top_categories(&liquor_by_zip, "output/top_zips_licenses.png", "Top ZIPs by License Count")?;
    plot_top_categories_strkey(&vacants_by_neighborhood, "output/top_neighborhoods_rehabs.png", "Top Neighborhoods by Rehabs")?;
    plot_year_comparison(&liquor, &vacants, "output/year_comparison.png")?;

    // keep earlier individual plots for convenience
    plot_license_fee_scatter(&liquor, "output/license_fee_scatter.png")?;

    println!("Reports written to reports/ and plots to output/");
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

fn profile_liquor_by_zip<P: AsRef<Path>>(path: P) -> Result<HashMap<String, usize>> {
    let mut rdr = csv::Reader::from_path(path)?;
    let headers = rdr.headers()?.clone();
    let zip_idx = headers.iter().position(|h| h == "AddrZip").unwrap_or(0);
    let mut counts: HashMap<String, usize> = HashMap::new();
    for result in rdr.records() {
        let record = result?;
        if let Some(zip) = record.get(zip_idx) {
            let z = zip.trim().to_string();
            if !z.is_empty() {
                *counts.entry(z).or_default() += 1;
            }
        }
    }
    Ok(counts)
}

fn profile_vacants_by_neighborhood<P: AsRef<Path>>(path: P) -> Result<HashMap<String, usize>> {
    let mut rdr = csv::Reader::from_path(path)?;
    let headers = rdr.headers()?.clone();
    let neigh_idx = headers.iter().position(|h| h == "Neighborhood").unwrap_or(0);
    let mut counts: HashMap<String, usize> = HashMap::new();
    for result in rdr.records() {
        let record = result?;
        if let Some(neigh) = record.get(neigh_idx) {
            let n = neigh.trim().to_string();
            if !n.is_empty() {
                *counts.entry(n).or_default() += 1;
            }
        }
    }
    Ok(counts)
}

fn write_json_profile(map: &HashMap<String, usize>, out: &str) -> Result<()> {
    let json = serde_json::to_string_pretty(map)?;
    fs::write(out, json)?;
    Ok(())
}

fn plot_top_categories(map: &HashMap<String, usize>, out: &str, title: &str) -> Result<()> {
    // map keys are numeric-like strings (ZIPs). Plot top 20.
    let mut pairs: Vec<(&String, &usize)> = map.iter().collect();
    pairs.sort_by(|a, b| b.1.cmp(a.1));
    let top = pairs.into_iter().take(20).collect::<Vec<_>>();
    if top.is_empty() {
        return Ok(());
    }

    let labels: Vec<String> = top.iter().map(|(k, _)| (*k).clone()).collect();
    let values: Vec<usize> = top.iter().map(|(_, v)| **v).collect();
    let maxv = *values.iter().max().unwrap();

    let root = BitMapBackend::new(out, (1200, 600)).into_drawing_area();
    root.fill(&WHITE)?;
    let mut chart = ChartBuilder::on(&root)
        .caption(title, ("sans-serif", 20).into_font())
        .margin(10)
        .x_label_area_size(200)
        .y_label_area_size(60)
        .build_cartesian_2d(0usize..labels.len(), 0usize..(maxv + 5))?;

    chart.configure_mesh().disable_mesh().y_desc("Count").draw()?;

    chart.draw_series(values.iter().enumerate().map(|(i, v)| {
        Rectangle::new([(i, 0usize), (i + 1, *v)], BLUE.filled())
    }))?;

    // draw labels vertically
    for (i, label) in labels.iter().enumerate() {
        root.draw(&Text::new(
            label.clone(),
            ((i as i32 * 50 + 60), 560),
            ("sans-serif", 12).into_font().color(&BLACK).transform(FontTransform::Rotate90),
        ))?;
    }

    Ok(())
}

fn plot_top_categories_strkey(map: &HashMap<String, usize>, out: &str, title: &str) -> Result<()> {
    // similar to plot_top_categories but keep string labels readable
    plot_top_categories(map, out, title)
}

fn plot_year_comparison(liquor: &[LiquorRow], vacants: &[VacantRow], out: &str) -> Result<()> {
    let mut lic_counts: HashMap<i32, usize> = HashMap::new();
    for r in liquor {
        *lic_counts.entry(r.year).or_default() += 1;
    }
    let mut vac_counts: HashMap<i32, usize> = HashMap::new();
    for v in vacants {
        *vac_counts.entry(v.year).or_default() += 1;
    }
    let mut years: Vec<i32> = lic_counts.keys().chain(vac_counts.keys()).cloned().collect();
    years.sort();
    years.dedup();
    if years.is_empty() {
        return Ok(());
    }

    let min_year = *years.first().unwrap();
    let max_year = *years.last().unwrap();
    let maxv = lic_counts.values().chain(vac_counts.values()).cloned().max().unwrap_or(1);

    let root = BitMapBackend::new(out, (1000, 600)).into_drawing_area();
    root.fill(&WHITE)?;

    let mut chart = ChartBuilder::on(&root)
        .caption("Yearly Counts: Licenses vs Vacant Rehabs", ("sans-serif", 20).into_font())
        .margin(10)
        .x_label_area_size(40)
        .y_label_area_size(60)
        .build_cartesian_2d(min_year..max_year, 0usize..(maxv + 5))?;

    chart.configure_mesh().x_desc("Year").y_desc("Count").draw()?;

    chart.draw_series(LineSeries::new(
        years.iter().map(|y| (*y, *lic_counts.get(y).unwrap_or(&0))),
        &BLUE,
    ))?;

    chart.draw_series(LineSeries::new(
        years.iter().map(|y| (*y, *vac_counts.get(y).unwrap_or(&0))),
        &RED,
    ))?;

    Ok(())
}
