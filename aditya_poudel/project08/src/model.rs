/// One row from BPD_Arrests.csv
#[derive(Debug, Clone)]
pub struct Arrest {
    pub neighborhood: String,
    pub district: String,
    pub age: Option<u32>,
    pub gender: String,
    pub race: String,
    pub arrest_date: String,
    pub year: Option<u32>,
    pub offence: String,
}

/// One row from Vacant_Building_Notices.csv
#[derive(Debug, Clone)]
pub struct VacantBuilding {
    pub neighborhood: String,
    pub council_district: String,
    pub date_notice: String,
    pub year: Option<u32>,
    pub notice_num: String,
    pub typology: String,
}

/// Per-neighborhood joined statistics
#[derive(Debug)]
pub struct NeighborhoodStats {
    pub neighborhood: String,
    pub vacant_count: usize,
    pub arrest_count: usize,
    pub arrests_per_vacant: f64,
}

impl NeighborhoodStats {
    pub fn pearson_correlation(rows: &[Self]) -> f64 {
        let n = rows.len() as f64;
        if n < 2.0 { return 0.0; }
        let mean_x = rows.iter().map(|r| r.vacant_count as f64).sum::<f64>() / n;
        let mean_y = rows.iter().map(|r| r.arrest_count as f64).sum::<f64>() / n;
        let cov: f64 = rows.iter()
            .map(|r| (r.vacant_count as f64 - mean_x) * (r.arrest_count as f64 - mean_y))
            .sum();
        let std_x = (rows.iter()
            .map(|r| (r.vacant_count as f64 - mean_x).powi(2))
            .sum::<f64>() / n).sqrt();
        let std_y = (rows.iter()
            .map(|r| (r.arrest_count as f64 - mean_y).powi(2))
            .sum::<f64>() / n).sqrt();
        if std_x == 0.0 || std_y == 0.0 { return 0.0; }
        cov / (n * std_x * std_y)
    }

    pub fn interpret(r: f64) -> &'static str {
        if r >= 0.7 {
            "Strong positive correlation: neighborhoods with more vacant buildings have substantially more arrests."
        } else if r >= 0.4 {
            "Moderate positive correlation: neighborhoods with more vacant buildings tend to have more arrests."
        } else if r >= 0.1 {
            "Weak positive correlation: slight tendency for higher vacancy to accompany more arrests."
        } else if r >= -0.1 {
            "No meaningful correlation detected between vacancy counts and arrest volume."
        } else {
            "Negative correlation: higher vacancy associated with fewer arrests — may reflect underpolicing."
        }
    }
}