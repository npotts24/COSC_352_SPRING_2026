use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

// ── Reuse Part 1 types and streaming infrastructure ───────────────────────────
use csvprof::error::{ProfileError, Result};
use csvprof::profiler::{CsvSource, DataSource};
use csvprof::stats::ColumnAccumulator;

use crate::model::{Arrest, NeighborhoodStats, VacantBuilding};

/// Parse the year out of date strings like "2023/04/15 10:00:00+00" or "2023-04-15"
fn parse_year(s: &str) -> Option<u32> {
    s.split(|c| c == '/' || c == '-').next()?.parse().ok()
}

/// Profile a CSV file using Part 1's ColumnAccumulator (reuse).
fn profile_file(path: &str) -> Result<Vec<ColumnAccumulator>> {
    let f = File::open(path).map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
    let reader = csv::ReaderBuilder::new().has_headers(true).from_reader(BufReader::new(f));
    let mut src = CsvSource::new(reader);

    // Read headers from a fresh handle
    let headers: Vec<String> = {
        let f2 = File::open(path).map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
        let mut rdr = csv::ReaderBuilder::new().has_headers(true).from_reader(BufReader::new(f2));
        rdr.headers()?.iter().map(|s| s.to_string()).collect()
    };

    // Reuse Part 1's ColumnAccumulator for per-column profiling
    let mut accs: Vec<ColumnAccumulator> = headers
        .iter()
        .map(|h| ColumnAccumulator::new(h, 2000))
        .collect();

    src.stream(&headers, &mut |fields: &[&str]| {
        for (i, acc) in accs.iter_mut().enumerate() {
            acc.observe(fields.get(i).copied().unwrap_or(""));
        }
    })?;
    Ok(accs)
}

/// Load BPD_Arrests.csv — returns rows + column profiles (Part 1 reuse).
pub fn load_arrests(path: &str) -> Result<(Vec<Arrest>, Vec<ColumnAccumulator>)> {
    let accs = profile_file(path)?;

    let f = File::open(path).map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
    let mut rdr = csv::ReaderBuilder::new().has_headers(true).from_reader(BufReader::new(f));
    let hdrs = rdr.headers()?.clone();

    let col = |name: &str| hdrs.iter().position(|h| h.eq_ignore_ascii_case(name)).unwrap_or(usize::MAX);
    let (c_nbhd, c_dist, c_age, c_gender, c_race, c_date, c_off) = (
        col("Neighborhood"), col("District"), col("Age"),
        col("Gender"), col("Race"), col("ArrestDateTime"), col("IncidentOffence"),
    );

    let mut rows = Vec::new();
    let mut record = csv::StringRecord::new();
    while rdr.read_record(&mut record)? {
        let get = |i: usize| record.get(i).unwrap_or("").trim().to_string();
        let nbhd = get(c_nbhd);
        if nbhd.is_empty() { continue; }
        let date = get(c_date);
        let year = parse_year(&date);
        rows.push(Arrest {
            neighborhood: nbhd,
            district: get(c_dist),
            age: get(c_age).parse().ok(),
            gender: get(c_gender),
            race: get(c_race),
            arrest_date: date.clone(),
            year,
            offence: get(c_off),
        });
    }
    Ok((rows, accs))
}

/// Load Vacant_Building_Notices.csv — returns rows + column profiles.
pub fn load_vacants(path: &str) -> Result<(Vec<VacantBuilding>, Vec<ColumnAccumulator>)> {
    let accs = profile_file(path)?;

    let f = File::open(path).map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
    let mut rdr = csv::ReaderBuilder::new().has_headers(true).from_reader(BufReader::new(f));
    let hdrs = rdr.headers()?.clone();

    let col = |name: &str| hdrs.iter().position(|h| h.eq_ignore_ascii_case(name)).unwrap_or(usize::MAX);
    let (c_nbhd, c_dist, c_date, c_num, c_typo) = (
        col("Neighborhood"), col("Council_District"),
        col("DateNotice"), col("NoticeNum"), col("HousingMarketTypology2023"),
    );

    let mut rows = Vec::new();
    let mut record = csv::StringRecord::new();
    while rdr.read_record(&mut record)? {
        let get = |i: usize| record.get(i).unwrap_or("").trim().to_string();
        let nbhd = get(c_nbhd);
        if nbhd.is_empty() { continue; }
        let date = get(c_date);
        let year = parse_year(&date);
        rows.push(VacantBuilding {
            neighborhood: nbhd,
            council_district: get(c_dist),
            date_notice: date,
            year,
            notice_num: get(c_num),
            typology: get(c_typo),
        });
    }
    Ok((rows, accs))
}

/// Join arrests and vacants on Neighborhood, compute per-neighborhood stats.
pub fn join_on_neighborhood(
    arrests: &[Arrest],
    vacants: &[VacantBuilding],
) -> Vec<NeighborhoodStats> {
    let mut vcount: HashMap<String, usize> = HashMap::new();
    for v in vacants {
        *vcount.entry(v.neighborhood.clone()).or_default() += 1;
    }
    let mut acount: HashMap<String, usize> = HashMap::new();
    for a in arrests {
        *acount.entry(a.neighborhood.clone()).or_default() += 1;
    }

    // Only include neighborhoods present in BOTH datasets
    let mut stats: Vec<NeighborhoodStats> = vcount
        .keys()
        .filter(|n| acount.contains_key(*n))
        .map(|n| {
            let vacant_count = vcount[n];
            let arrest_count = acount[n];
            let arrests_per_vacant = if vacant_count == 0 {
                0.0
            } else {
                arrest_count as f64 / vacant_count as f64
            };
            NeighborhoodStats {
                neighborhood: n.clone(),
                vacant_count,
                arrest_count,
                arrests_per_vacant,
            }
        })
        .collect();

    stats.sort_by(|a, b| b.vacant_count.cmp(&a.vacant_count));
    stats
}