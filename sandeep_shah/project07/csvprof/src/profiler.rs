use crate::error::AppError;
use crate::stats::{ColumnProfile, ColumnSummary};
use anyhow::Result;
use csv::{ReaderBuilder, StringRecord};
use serde::Serialize;
use std::fs::File;
use std::io::{self, Read};

#[derive(Debug, Clone)]
pub struct ProfileConfig {
    pub delimiter: u8,
    pub has_headers: bool,
    pub percentiles: bool,
    pub histogram: bool,
    pub max_categories: usize,
    pub categorical_ratio: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct ProfileReport {
    pub total_rows: u64,
    pub total_columns: usize,
    pub columns: Vec<ColumnSummary>,
}

pub fn profile_csv(path: &str, cfg: &ProfileConfig) -> Result<ProfileReport> {
    let reader: Box<dyn Read> = if path == "-" {
        Box::new(io::stdin())
    } else {
        Box::new(File::open(path).map_err(|source| AppError::OpenInput {
            path: path.to_string(),
            source,
        })?)
    };

    let mut rdr = ReaderBuilder::new()
        .delimiter(cfg.delimiter)
        .has_headers(cfg.has_headers)
        .from_reader(reader);

    let headers: Vec<String> = if cfg.has_headers {
        rdr.headers()?
            .iter()
            .map(|s: &str| s.to_string())
            .collect::<Vec<String>>()
    } else {
        let first_record: StringRecord = match rdr.records().next() {
            Some(r) => r?,
            None => {
                return Ok(ProfileReport {
                    total_rows: 0,
                    total_columns: 0,
                    columns: Vec::new(),
                });
            }
        };

        let col_count: usize = first_record.len();
        let generated_headers: Vec<String> = (0..col_count)
            .map(|i| format!("column_{}", i + 1))
            .collect();

        let mut profiles: Vec<ColumnProfile> = generated_headers
            .iter()
            .map(|h: &String| ColumnProfile::new(h.clone()))
            .collect();

        for (i, field) in first_record.iter().enumerate() {
            profiles[i].update(field);
        }

        let mut total_rows: u64 = 1;

        for record in rdr.records() {
            let record: StringRecord = record?;
            total_rows += 1;

            for (i, field) in record.iter().enumerate() {
                if let Some(profile) = profiles.get_mut(i) {
                    profile.update(field);
                }
            }

            if record.len() < profiles.len() {
                for profile in profiles.iter_mut().skip(record.len()) {
                    profile.update("");
                 }
            }
        }

        let columns: Vec<ColumnSummary> = profiles
            .iter()
            .map(|p: &ColumnProfile| {
                p.finalize(
                    cfg.percentiles,
                    cfg.histogram,
                    cfg.max_categories,
                    cfg.categorical_ratio,
                )
            })
            .collect();

        return Ok(ProfileReport {
            total_rows,
            total_columns: col_count,
            columns,
        });
    };

    let mut profiles: Vec<ColumnProfile> = headers
        .iter()
        .map(|h: &String| ColumnProfile::new(h.clone()))
        .collect();

    let mut total_rows: u64 = 0;

    for record in rdr.records() {
        let record: StringRecord = record?;
        total_rows += 1;

        for (i, field) in record.iter().enumerate() {
            if let Some(profile) = profiles.get_mut(i) {
                profile.update(field);
            }
        }

        if record.len() < profiles.len() {
            for profile in profiles.iter_mut().skip(record.len()) {
                profile.update("");
            }
        }
    }

    let columns: Vec<ColumnSummary> = profiles
        .iter()
        .map(|p: &ColumnProfile| {
            p.finalize(
                cfg.percentiles,
                cfg.histogram,
                cfg.max_categories,
                cfg.categorical_ratio,
            )
        })
        .collect();

    Ok(ProfileReport {
        total_rows,
        total_columns: headers.len(),
        columns,
    })
}
