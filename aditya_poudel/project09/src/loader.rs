use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;

use csvprof::error::{ProfileError, Result};
use csvprof::profiler::{CsvSource, DataSource};
use csvprof::stats::ColumnAccumulator;

#[derive(Debug, Clone)]
pub struct Arrest {
    pub neighborhood: String,
}

#[derive(Debug, Clone)]
pub struct VacantBuilding {
    pub neighborhood: String,
}

#[derive(Debug)]
pub struct NeighborhoodStats {
    pub neighborhood: String,
    pub vacant_count: usize,
    pub arrest_count: usize,
    pub arrests_per_vacant: f64,
}

fn profile_file(path: &str) -> Result<Vec<ColumnAccumulator>> {
    let f = File::open(path)
        .map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
    let reader = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_reader(BufReader::new(f));
    let mut src = CsvSource::new(reader);

    let headers: Vec<String> = {
        let f2 = File::open(path)
            .map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
        let mut rdr = csv::ReaderBuilder::new()
            .has_headers(true)
            .from_reader(BufReader::new(f2));
        rdr.headers()?.iter().map(|s| s.to_string()).collect()
    };

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

pub fn load_arrests(path: &str) -> Result<(Vec<Arrest>, Vec<ColumnAccumulator>)> {
    let accs = profile_file(path)?;
    let f = File::open(path)
        .map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_reader(BufReader::new(f));
    let hdrs = rdr.headers()?.clone();
    let c_nbhd = hdrs.iter()
        .position(|h| h.eq_ignore_ascii_case("Neighborhood"))
        .unwrap_or(usize::MAX);
    let mut rows = Vec::new();
    let mut record = csv::StringRecord::new();
    while rdr.read_record(&mut record)? {
        let nbhd = record.get(c_nbhd).unwrap_or("").trim().to_string();
        if !nbhd.is_empty() {
            rows.push(Arrest { neighborhood: nbhd });
        }
    }
    Ok((rows, accs))
}

pub fn load_vacants(path: &str) -> Result<(Vec<VacantBuilding>, Vec<ColumnAccumulator>)> {
    let accs = profile_file(path)?;
    let f = File::open(path)
        .map_err(|_| ProfileError::FileNotFound { path: path.into() })?;
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(true)
        .from_reader(BufReader::new(f));
    let hdrs = rdr.headers()?.clone();
    let c_nbhd = hdrs.iter()
        .position(|h| h.eq_ignore_ascii_case("Neighborhood"))
        .unwrap_or(usize::MAX);
    let mut rows = Vec::new();
    let mut record = csv::StringRecord::new();
    while rdr.read_record(&mut record)? {
        let nbhd = record.get(c_nbhd).unwrap_or("").trim().to_string();
        if !nbhd.is_empty() {
            rows.push(VacantBuilding { neighborhood: nbhd });
        }
    }
    Ok((rows, accs))
}

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