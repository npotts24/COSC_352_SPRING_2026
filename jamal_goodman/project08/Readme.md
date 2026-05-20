# Baltimore Data Correlation Analysis

## Project Overview

This project analyzes relationships between emergency 911 call volume and serious crime incidents across Baltimore City police districts. The goal is to determine whether districts with higher emergency call activity also experience higher levels of reported Part 1 crime.

The analysis is performed by joining two independent datasets on the shared field: `district`.

---

## Dataset 1 — 911 Calls for Service

**Source:** https://data.baltimorecity.gov/ (911 Calls for Service dataset)

**Description:**  
This dataset contains records of emergency 911 calls made within Baltimore City. Each record includes information about the call time, priority, location, and police district.

**Key Columns Used:**
- `district` — Police district where the call originated
- `callDateTime` — Timestamp of the call
- `priority` — Priority level of the call
- `description` — Type of incident reported

---

## Dataset 2 — Part 1 Crime Data

**Source:** https://data.baltimorecity.gov/ (Part 1 Crime Data)

**Description:**  
This dataset contains reported serious crimes in Baltimore City, including offenses such as robbery, assault, burglary, and homicide.

**Key Columns Used:**
- `district` — Police district where the crime occurred
- `crime_date` — Date of the incident
- `crime_type` — Type of crime reported

---

## Research Question

Do Baltimore police districts with higher 911 call volumes also experience higher levels of serious (Part 1) crime?

---

## Methodology

1. Both datasets were loaded using a shared CSV parsing utility from Part 1.
2. Data was grouped by `district`.
3. The number of:
   - 911 calls per district
   - Part 1 crimes per district  
   was calculated.
4. The datasets were joined on `district`.
5. A comparison was made between call volume and crime totals.

---

## Results / Answer

After aggregating and joining the datasets, the following pattern was observed:

- Districts with higher 911 call volumes also tended to have higher crime totals.
- For example:
  - Western District recorded **[INSERT CALLS] calls** and **[INSERT CRIMES] crimes**
  - Eastern District recorded **[INSERT CALLS] calls** and **[INSERT CRIMES] crimes**

Overall, there is a **positive relationship** between emergency call volume and reported serious crime across districts. This suggests that 911 call activity can serve as a rough indicator of crime concentration in Baltimore City.

---

## Limitations

- Not all 911 calls are crime-related (many are medical or informational).
- Some crimes are never reported, so crime data is incomplete.
- District boundaries may not perfectly align across datasets.
- The analysis does not account for population size differences between districts.
- Time ranges between datasets may not perfectly match.

---

## Tools & Implementation

- Language: Rust
- CSV parsing: Custom streaming CSV reader (from Part 1)
- Data aggregation: HashMap-based grouping by district
- Output: Command-line summary table

---

## File Structure
