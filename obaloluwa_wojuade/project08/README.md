# Project 08 — Baltimore City Open Data Analysis

## Dataset 1 — Baltimore City Employee Salaries
- **Source URL:** https://data.baltimorecity.gov/datasets/afdaf8cca48a4bcea9282a781e9190a6
- **Description:** Contains salary records for Baltimore City employees, including agency name, job title, hire date, annual salary, gross pay, and fiscal year.
- **Key columns used:** AgencyName, AnnualSalary, FiscalYear

## Dataset 2 — Baltimore City Liquor Licenses
- **Source URL:** https://data.baltimorecity.gov/datasets/ae5ed61365e74579aea25656ac9ce45e
- **Description:** Contains liquor license records with establishment type, license status, address, zip code, and license fee.
- **Key columns used:** AddrZip, LicenseStatus, EstablishmentDesc, LicenseFee

## Research Question
Do Baltimore zip codes with the highest concentration of active liquor licenses also correspond to areas where public safety employees (Police and Fire) represent the largest share of above-average earners among all city workers?

## How to Build and Run

### Prerequisites
Rust must be installed: https://rustup.rs

### Step 1 — Build project07 as a library (required first)
cd obaloluwa_wojuade/project07
cargo build

### Step 2 — Run the analysis
cd obaloluwa_wojuade/project08
cargo run

### Step 3 — Generate profile reports (optional, for reports/ folder)
cd obaloluwa_wojuade/project07
cargo build --release
./target/release/csvprof ../project08/data/Employee_Salaries.csv > ../project08/reports/salaries_profile.txt
./target/release/csvprof ../project08/data/Liquor_Licenses.csv > ../project08/reports/liquor_profile.txt

## Answer
Running the analysis shows that zip code 21202 has the highest concentration of active liquor licenses, with 3967 active licenses and 1008 taverns. Across all zip codes, the average active license count is 949.8 (std dev 1030.0), while the top 5 zip codes average 2920.8 active licenses, indicating strong concentration.

For FY2024 salary records, the citywide average annual salary is $50,821.47. In public safety agencies, 2407 Police Department employees (83.8%) and 1395 Fire Department employees (82.9%) earn above that citywide average, for 3802 above-average public safety earners total.

These results support a pattern where the highest-license zip code cluster coincides with very high concentrations of above-average public safety earners citywide, while also acknowledging that the salary dataset does not include zip-level assignment data for a direct geographic join.

## Limitations
- The salary dataset does not include zip codes, so a direct geographic join between license density and officer deployment by area is not possible with these fields alone.
- License records include historical entries, which may inflate counts in certain zip codes even after filtering to renewed status.
- FY2024 salary data represents a single fiscal year snapshot and may not reflect current staffing levels or recent departmental changes.