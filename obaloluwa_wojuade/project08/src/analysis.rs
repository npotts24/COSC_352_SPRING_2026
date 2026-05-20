use csvprof::stats::{mean, std_dev};

use crate::error::{AnalysisError, Result};
use crate::join::{PublicSafetyStats, ZipLiquorStats};

#[derive(Debug)]
pub struct Finding {
    pub top_zip: String,
    pub top_zip_active_licenses: usize,
    pub top_zip_taverns: usize,
    pub avg_active_licenses_per_zip: f64,
    pub std_dev_active_licenses: f64,
    pub police_pct_above_avg: f64,
    pub fire_pct_above_avg: f64,
    pub overall_above_avg_public_safety: usize,
    pub summary: String,
}

pub fn analyze(zip_stats: &[ZipLiquorStats], salary: &PublicSafetyStats) -> Result<Finding> {
    let active_license_counts: Vec<f64> = zip_stats.iter().map(|zip| zip.active_licenses as f64).collect();
    let avg_active_licenses = mean(&active_license_counts).unwrap_or(0.0);
    let stddev_active_licenses = std_dev(&active_license_counts).unwrap_or(0.0);
    let top_five_active_counts: Vec<f64> = zip_stats.iter().take(5).map(|zip| zip.active_licenses as f64).collect();
    let top_five_avg = mean(&top_five_active_counts).unwrap_or(0.0);

    let top = zip_stats.first().ok_or_else(|| {
        AnalysisError::Analysis("No zip-level liquor data available after filtering".to_string())
    })?;

    let police_pct = if salary.police_count > 0 {
        (salary.above_avg_police as f64 / salary.police_count as f64) * 100.0
    } else {
        0.0
    };

    let fire_pct = if salary.fire_count > 0 {
        (salary.above_avg_fire as f64 / salary.fire_count as f64) * 100.0
    } else {
        0.0
    };

    let top_five: Vec<String> = zip_stats
        .iter()
        .take(5)
        .map(|zip| format!("{} ({} active, {} taverns)", zip.zip, zip.active_licenses, zip.tavern_count))
        .collect();

    let summary = format!(
        "Top zip code {} has {} active liquor licenses, including {} taverns. The top 5 zip codes average {:.1} active licenses each, while all zip codes in the dataset average {:.1} active licenses (std dev {:.1}). In FY2024, the citywide average salary was ${:.2}, and {} Police Department employees plus {} Fire Department employees earned above that average, for {} public safety above-average earners total. This points to a concentration of active liquor activity in a small set of zip codes, but the salary data only supports a citywide staffing comparison rather than a direct geographic correlation. Top 5 zip codes: {}.",
        top.zip,
        top.active_licenses,
        top.tavern_count,
        top_five_avg,
        avg_active_licenses,
        stddev_active_licenses,
        salary.citywide_avg_salary,
        salary.above_avg_police,
        salary.above_avg_fire,
        salary.above_avg_public_safety,
        top_five.join(", ")
    );

    Ok(Finding {
        top_zip: top.zip.clone(),
        top_zip_active_licenses: top.active_licenses,
        top_zip_taverns: top.tavern_count,
        avg_active_licenses_per_zip: avg_active_licenses,
        std_dev_active_licenses: stddev_active_licenses,
        police_pct_above_avg: police_pct,
        fire_pct_above_avg: fire_pct,
        overall_above_avg_public_safety: salary.above_avg_public_safety,
        summary,
    })
}