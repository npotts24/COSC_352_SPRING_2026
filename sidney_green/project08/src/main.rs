use project08::{BaltimoreData, DataProfiler, count_by_district};
use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    let (rows, _profiles) = BaltimoreData::profile_csv("data/gun_offenders.csv")?;
    println!("Part 1 logic: Successfully profiled {} rows from Gun Offenders dataset.", rows);

    let offender_counts = count_by_district("data/gun_offenders.csv", "District")?;
    let arrest_counts = count_by_district("data/bpd_arrests.csv", "District")?;

    println!("\nDistrict   | Gun Offenders | Total BPD Arrests");
    println!("----------------------------------------------");
    
    for (district, o_count) in offender_counts {
        if let Some(a_count) = arrest_counts.get(&district) {
            println!("{:<10} | {:<13} | {:<17}", district, o_count, a_count);
        }
    }

    Ok(())
}