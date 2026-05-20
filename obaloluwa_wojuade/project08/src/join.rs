use crate::loader::Row;
use csvprof::stats::{mean, std_dev};
use std::collections::HashMap;

pub trait Joinable {
    fn extract_key(&self, row: &Row) -> Option<String>;
    fn dataset_name(&self) -> &str;
}

pub struct LiquorZipKey;
pub struct SalaryAgencyKey;

impl Joinable for LiquorZipKey {
    fn extract_key(&self, row: &Row) -> Option<String> {
        row.get("AddrZip")
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty() && v.chars().all(|c| c.is_ascii_digit()))
    }

    fn dataset_name(&self) -> &str {
        "Liquor Licenses"
    }
}

impl Joinable for SalaryAgencyKey {
    fn extract_key(&self, row: &Row) -> Option<String> {
        row.get("AgencyName")
            .map(|v| v.trim().to_string())
            .filter(|v| !v.is_empty())
    }

    fn dataset_name(&self) -> &str {
        "Employee Salaries"
    }
}

#[derive(Debug, Clone)]
pub struct ZipLiquorStats {
    pub zip: String,
    pub total_licenses: usize,
    pub active_licenses: usize,
    pub tavern_count: usize,
    pub restaurant_count: usize,
    pub package_goods_count: usize,
    pub avg_license_fee: f64,
}

#[derive(Debug, Clone)]
pub struct PublicSafetyStats {
    pub total_employees: usize,
    pub police_count: usize,
    pub fire_count: usize,
    pub citywide_avg_salary: f64,
    pub citywide_salary_std_dev: f64,
    pub police_avg_salary: f64,
    pub fire_avg_salary: f64,
    pub above_avg_police: usize,
    pub above_avg_fire: usize,
    pub above_avg_public_safety: usize,
}

pub fn build_zip_stats(rows: &[Row]) -> Vec<ZipLiquorStats> {
    let key = LiquorZipKey;
    let mut map: HashMap<String, ZipLiquorStats> = HashMap::new();

    for row in rows {
        let Some(zip) = key.extract_key(row) else {
            continue;
        };

        let status = row.get("LicenseStatus").map(|s| s.trim()).unwrap_or("");
        let desc = row.get("EstablishmentDesc").map(|s| s.trim()).unwrap_or("");
        let fee = row
            .get("LicenseFee")
            .and_then(|s| s.trim().parse::<f64>().ok())
            .unwrap_or(0.0);

        let entry = map.entry(zip.clone()).or_insert(ZipLiquorStats {
            zip: zip.clone(),
            total_licenses: 0,
            active_licenses: 0,
            tavern_count: 0,
            restaurant_count: 0,
            package_goods_count: 0,
            avg_license_fee: 0.0,
        });

        entry.total_licenses += 1;
        if status == "Renewed" {
            entry.active_licenses += 1;
        }
        if desc == "Tavern" || desc == "Tavern License" {
            entry.tavern_count += 1;
        }
        if desc == "Restaurant" || desc == "Restaurant License" {
            entry.restaurant_count += 1;
        }
        if desc == "Package goods only" || desc == "Package Goods Only" {
            entry.package_goods_count += 1;
        }
        entry.avg_license_fee += fee;
    }

    for stat in map.values_mut() {
        if stat.total_licenses > 0 {
            stat.avg_license_fee /= stat.total_licenses as f64;
        }
    }

    let mut result: Vec<ZipLiquorStats> = map.into_values().collect();
    result.sort_by(|a, b| {
        b.active_licenses
            .cmp(&a.active_licenses)
            .then_with(|| b.tavern_count.cmp(&a.tavern_count))
            .then_with(|| a.zip.cmp(&b.zip))
    });
    result
}

pub fn build_salary_stats(rows: &[Row]) -> PublicSafetyStats {
    let fy2024: Vec<&Row> = rows
        .iter()
        .filter(|row| row.get("FiscalYear").map(|s| s.trim()) == Some("FY2024"))
        .collect();

    let all_salaries: Vec<f64> = fy2024
        .iter()
        .filter_map(|row| row.get("AnnualSalary"))
        .filter_map(|value| value.trim().parse::<f64>().ok())
        .collect();

    let citywide_avg = mean(&all_salaries).unwrap_or(0.0);
    let citywide_std_dev = std_dev(&all_salaries).unwrap_or(0.0);

    let police: Vec<f64> = fy2024
        .iter()
        .filter(|row| row.get("AgencyName").map(|s| s.trim()) == Some("Police Department"))
        .filter_map(|row| row.get("AnnualSalary"))
        .filter_map(|value| value.trim().parse::<f64>().ok())
        .collect();

    let fire: Vec<f64> = fy2024
        .iter()
        .filter(|row| row.get("AgencyName").map(|s| s.trim()) == Some("Fire Department"))
        .filter_map(|row| row.get("AnnualSalary"))
        .filter_map(|value| value.trim().parse::<f64>().ok())
        .collect();

    let police_avg = mean(&police).unwrap_or(0.0);
    let fire_avg = mean(&fire).unwrap_or(0.0);

    let above_avg_police = police.iter().filter(|&&salary| salary > citywide_avg).count();
    let above_avg_fire = fire.iter().filter(|&&salary| salary > citywide_avg).count();

    PublicSafetyStats {
        total_employees: fy2024.len(),
        police_count: police.len(),
        fire_count: fire.len(),
        citywide_avg_salary: citywide_avg,
        citywide_salary_std_dev: citywide_std_dev,
        police_avg_salary: police_avg,
        fire_avg_salary: fire_avg,
        above_avg_police,
        above_avg_fire,
        above_avg_public_safety: above_avg_police + above_avg_fire,
    }
}