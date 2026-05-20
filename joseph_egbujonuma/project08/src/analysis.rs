use csv::Reader;
use chrono::{NaiveDate, Duration};

#[derive(Debug)]
pub struct Arrest {
    pub date: NaiveDate,
}

#[derive(Debug)]
pub struct Demo {
    pub date: NaiveDate,
}

pub fn run_analysis() -> Result<(), Box<dyn std::error::Error>> {
    let arrests = load_arrests("data/BPD_Arrests.csv")?;
    let demos = load_demos("data/Completed_City_Demo.csv")?;

    let mut before_count = 0;
    let mut after_count = 0;

    for demo in &demos {
        for arrest in &arrests {
            let diff = arrest.date - demo.date;

            if diff >= Duration::days(-30) && diff < Duration::days(0) {
                before_count += 1;
            } else if diff > Duration::days(0) && diff <= Duration::days(30) {
                after_count += 1;
            }
        }
    }

    println!("=== ANALYSIS RESULT ===");
    println!("Arrests 30 days BEFORE demolitions: {}", before_count);
    println!("Arrests 30 days AFTER demolitions: {}", after_count);

    if before_count > 0 {
        let change = ((after_count as f64 - before_count as f64) / before_count as f64) * 100.0;
        println!("Percent change: {:.2}%", change);
    }

    Ok(())
}

fn load_arrests(path: &str) -> Result<Vec<Arrest>, Box<dyn std::error::Error>> {
    let mut rdr = Reader::from_path(path)?;
    let mut arrests = Vec::new();

    for result in rdr.records() {
        let record = result?;
        let date_str = &record[1]; // adjust if needed

        if let Ok(date) = NaiveDate::parse_from_str(date_str, "%Y-%m-%d") {
            arrests.push(Arrest { date });
        }
    }

    Ok(arrests)
}

fn load_demos(path: &str) -> Result<Vec<Demo>, Box<dyn std::error::Error>> {
    let mut rdr = Reader::from_path(path)?;
    let mut demos = Vec::new();

    for result in rdr.records() {
        let record = result?;
        let date_str = &record[2]; // adjust if needed

        if let Ok(date) = NaiveDate::parse_from_str(date_str, "%Y-%m-%d") {
            demos.push(Demo { date });
        }
    }

    Ok(demos)
}