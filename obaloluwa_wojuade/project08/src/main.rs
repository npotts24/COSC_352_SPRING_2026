mod analysis;
mod error;
mod join;
mod loader;
mod report;

use crate::analysis::analyze;
use crate::error::Result;
use crate::join::{build_salary_stats, build_zip_stats};
use crate::loader::StreamingLoader;

fn main() {
    if let Err(error) = run() {
        eprintln!("Error: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let salaries_path = "data/Employee_Salaries.csv";
    let liquor_path = "data/Liquor_Licenses.csv";

    println!("Loading employee salaries from {}...", salaries_path);
    let salaries = StreamingLoader::load_columns(
        salaries_path,
        &["AgencyName", "AnnualSalary", "FiscalYear"],
    )?;
    println!("  {} rows loaded", salaries.len());

    println!("Loading liquor licenses from {}...", liquor_path);
    let liquor = StreamingLoader::load_columns(
        liquor_path,
        &["AddrZip", "LicenseStatus", "EstablishmentDesc", "LicenseFee"],
    )?;
    println!("  {} rows loaded\n", liquor.len());

    let zip_stats = build_zip_stats(&liquor);
    let salary_stats = build_salary_stats(&salaries);

    report::print_zip_table(&zip_stats, 15);
    report::print_salary_summary(&salary_stats);

    let finding = analyze(&zip_stats, &salary_stats)?;
    report::print_finding(&finding);

    Ok(())
}