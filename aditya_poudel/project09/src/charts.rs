use plotters::prelude::*;
use crate::loader::NeighborhoodStats;
use csvprof::stats::ColumnReport;

const W: u32 = 1200;
const H: u32 = 700;

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("{}…", &s[..max.saturating_sub(1)])
    }
}

/// Chart 1 — Scatter: vacant buildings vs arrests with trend line
pub fn scatter_vacants_vs_arrests(
    stats: &[NeighborhoodStats],
    path: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let root = BitMapBackend::new(path, (W, H)).into_drawing_area();
    root.fill(&RGBColor(248, 249, 250))?;

    let max_v = stats.iter().map(|s| s.vacant_count).max().unwrap_or(1) as f64 * 1.1;
    let max_a = stats.iter().map(|s| s.arrest_count).max().unwrap_or(1) as f64 * 1.1;

    let mut chart = ChartBuilder::on(&root)
        .caption(
            "Vacant Buildings vs Arrests by Neighborhood",
            ("sans-serif", 24).into_font(),
        )
        .margin(50)
        .x_label_area_size(50)
        .y_label_area_size(70)
        .build_cartesian_2d(0f64..max_v, 0f64..max_a)?;

    chart.configure_mesh()
        .x_desc("Vacant Building Notices")
        .y_desc("Arrest Count")
        .axis_desc_style(("sans-serif", 14))
        .draw()?;

    // Scatter points
    chart.draw_series(
        stats.iter().map(|s| {
            Circle::new(
                (s.vacant_count as f64, s.arrest_count as f64),
                5,
                RGBColor(52, 120, 246).mix(0.65).filled(),
            )
        })
    )?.label("Neighborhood")
      .legend(|(x, y)| Circle::new((x + 10, y), 5, RGBColor(52, 120, 246).filled()));

    // Linear regression trend line
    let n = stats.len() as f64;
    let mx = stats.iter().map(|s| s.vacant_count as f64).sum::<f64>() / n;
    let my = stats.iter().map(|s| s.arrest_count as f64).sum::<f64>() / n;
    let slope = stats.iter()
        .map(|s| (s.vacant_count as f64 - mx) * (s.arrest_count as f64 - my))
        .sum::<f64>()
        / stats.iter()
            .map(|s| (s.vacant_count as f64 - mx).powi(2))
            .sum::<f64>();
    let intercept = my - slope * mx;

    chart.draw_series(LineSeries::new(
        vec![(0f64, intercept), (max_v, slope * max_v + intercept)],
        RGBColor(220, 50, 47).stroke_width(2),
    ))?.label("Trend line (r=0.64)")
      .legend(|(x, y)| PathElement::new(
          vec![(x, y), (x + 20, y)],
          RGBColor(220, 50, 47).stroke_width(2),
      ));

    chart.configure_series_labels()
        .background_style(WHITE.mix(0.8))
        .border_style(BLACK)
        .draw()?;

    root.present()?;
    Ok(())
}

/// Chart 2 — Vertical bar: top N neighborhoods by vacancy count
pub fn bar_top_vacancies(
    stats: &[NeighborhoodStats],
    path: &str,
    top_n: usize,
) -> Result<(), Box<dyn std::error::Error>> {
    let data: Vec<_> = stats.iter().take(top_n).collect();
    let max_val = data.iter().map(|s| s.vacant_count).max().unwrap_or(1) as u32 + 50;

    let root = BitMapBackend::new(path, (W, H)).into_drawing_area();
    root.fill(&RGBColor(248, 249, 250))?;

    let mut chart = ChartBuilder::on(&root)
        .caption(
            format!("Top {} Neighborhoods by Vacant Building Count", top_n),
            ("sans-serif", 22).into_font(),
        )
        .margin(50)
        .x_label_area_size(120)
        .y_label_area_size(70)
        .build_cartesian_2d(
            (0..data.len()).into_segmented(),
            0u32..max_val,
        )?;

    chart.configure_mesh()
        .y_desc("Vacant Building Notices")
        .axis_desc_style(("sans-serif", 13))
        .x_labels(data.len())
        .x_label_style(("sans-serif", 10))
        .x_label_formatter(&|idx| {
            if let SegmentValue::CenterOf(i) = idx {
                data.get(*i)
                    .map(|s| truncate(&s.neighborhood, 18))
                    .unwrap_or_default()
            } else { String::new() }
        })
        .draw()?;

    chart.draw_series(data.iter().enumerate().map(|(i, s)| {
        let mut bar = Rectangle::new(
            [(SegmentValue::Exact(i), 0), (SegmentValue::Exact(i + 1), s.vacant_count as u32)],
            RGBColor(255, 140, 0).mix(0.85).filled(),
        );
        bar.set_margin(0, 0, 3, 3);
        bar
    }))?;

    root.present()?;
    Ok(())
}

/// Chart 3 — Vertical bar: top N neighborhoods by arrest count
pub fn bar_top_arrests(
    stats: &[NeighborhoodStats],
    path: &str,
    top_n: usize,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut sorted = stats.iter().collect::<Vec<_>>();
    sorted.sort_by(|a, b| b.arrest_count.cmp(&a.arrest_count));
    let data: Vec<_> = sorted.iter().take(top_n).collect();
    let max_val = data.iter().map(|s| s.arrest_count).max().unwrap_or(1) as u32 + 200;

    let root = BitMapBackend::new(path, (W, H)).into_drawing_area();
    root.fill(&RGBColor(248, 249, 250))?;

    let mut chart = ChartBuilder::on(&root)
        .caption(
            format!("Top {} Neighborhoods by Arrest Count", top_n),
            ("sans-serif", 22).into_font(),
        )
        .margin(50)
        .x_label_area_size(120)
        .y_label_area_size(70)
        .build_cartesian_2d(
            (0..data.len()).into_segmented(),
            0u32..max_val,
        )?;

    chart.configure_mesh()
        .y_desc("Arrest Count")
        .axis_desc_style(("sans-serif", 13))
        .x_labels(data.len())
        .x_label_style(("sans-serif", 10))
        .x_label_formatter(&|idx| {
            if let SegmentValue::CenterOf(i) = idx {
                data.get(*i)
                    .map(|s| truncate(&s.neighborhood, 18))
                    .unwrap_or_default()
            } else { String::new() }
        })
        .draw()?;

    chart.draw_series(data.iter().enumerate().map(|(i, s)| {
        let mut bar = Rectangle::new(
            [(SegmentValue::Exact(i), 0), (SegmentValue::Exact(i + 1), s.arrest_count as u32)],
            RGBColor(220, 50, 47).mix(0.85).filled(),
        );
        bar.set_margin(0, 0, 3, 3);
        bar
    }))?;

    root.present()?;
    Ok(())
}

/// Chart 4 — Histogram: distribution of arrests-per-vacant ratio
pub fn hist_ratio(
    stats: &[NeighborhoodStats],
    path: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let ratios: Vec<f64> = stats.iter()
        .map(|s| s.arrests_per_vacant.min(200.0))
        .collect();

    let bins = 20usize;
    let max_r = 200f64;
    let bin_w = max_r / bins as f64;
    let mut counts = vec![0u32; bins];
    for r in &ratios {
        let idx = (*r / bin_w).floor() as usize;
        counts[idx.min(bins - 1)] += 1;
    }
    let max_count = *counts.iter().max().unwrap_or(&1) + 2;

    let root = BitMapBackend::new(path, (W, H)).into_drawing_area();
    root.fill(&RGBColor(248, 249, 250))?;

    let mut chart = ChartBuilder::on(&root)
        .caption(
            "Distribution of Arrests per Vacant Building (by Neighborhood)",
            ("sans-serif", 20).into_font(),
        )
        .margin(50)
        .x_label_area_size(50)
        .y_label_area_size(60)
        .build_cartesian_2d(0f64..max_r, 0u32..max_count)?;

    chart.configure_mesh()
        .x_desc("Arrests per Vacant Building (capped at 200)")
        .y_desc("Number of Neighborhoods")
        .axis_desc_style(("sans-serif", 13))
        .draw()?;

    chart.draw_series(counts.iter().enumerate().map(|(i, &c)| {
        let x0 = i as f64 * bin_w;
        let x1 = x0 + bin_w;
        Rectangle::new(
            [(x0, 0), (x1, c)],
            RGBColor(42, 157, 143).mix(0.8).filled(),
        )
    }))?;

    root.present()?;
    Ok(())
}

/// Chart 5 — Bar: null rates from csvprof Part 1 column profiles
pub fn bar_null_rates(
    arrest_reports: &[ColumnReport],
    vacant_reports: &[ColumnReport],
    path: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let arrest_nulls: Vec<(String, f64)> = arrest_reports.iter()
        .filter(|r| r.null_pct > 0.0)
        .take(8)
        .map(|r| (truncate(&r.name, 18), r.null_pct))
        .collect();

    let vacant_nulls: Vec<(String, f64)> = vacant_reports.iter()
        .filter(|r| r.null_pct > 0.0)
        .take(8)
        .map(|r| (truncate(&r.name, 18), r.null_pct))
        .collect();

    let root = BitMapBackend::new(path, (W, H)).into_drawing_area();
    root.fill(&RGBColor(248, 249, 250))?;
    let (top, bottom) = root.split_vertically(H / 2);

    draw_null_panel(&top,    &arrest_nulls, "BPD Arrests — Column Null Rates (%)",     RGBColor(52, 120, 246))?;
    draw_null_panel(&bottom, &vacant_nulls, "Vacant Buildings — Column Null Rates (%)", RGBColor(255, 140, 0))?;

    root.present()?;
    Ok(())
}

fn draw_null_panel(
    area: &DrawingArea<BitMapBackend, plotters::coord::Shift>,
    data: &[(String, f64)],
    title: &str,
    color: RGBColor,
) -> Result<(), Box<dyn std::error::Error>> {
    if data.is_empty() { return Ok(()); }
    let max_pct = data.iter().map(|(_, p)| *p).fold(0f64, f64::max).max(1.0) * 1.15;
    let n = data.len();

    let mut chart = ChartBuilder::on(area)
        .caption(title, ("sans-serif", 15).into_font())
        .margin(25)
        .x_label_area_size(35)
        .y_label_area_size(150)
        .build_cartesian_2d(0f64..max_pct, (0..n).into_segmented())?;

    chart.configure_mesh()
        .x_desc("Null %")
        .axis_desc_style(("sans-serif", 11))
        .y_labels(n)
        .y_label_formatter(&|idx| {
            if let SegmentValue::CenterOf(i) = idx {
                data.get(*i).map(|(name, _)| name.clone()).unwrap_or_default()
            } else { String::new() }
        })
        .draw()?;

    chart.draw_series(data.iter().enumerate().map(|(i, (_, pct))| {
        let mut bar = Rectangle::new(
            [(0f64, SegmentValue::Exact(i)), (*pct, SegmentValue::Exact(i + 1))],
            color.mix(0.75).filled(),
        );
        bar.set_margin(4, 4, 0, 0);
        bar
    }))?;

    Ok(())
}