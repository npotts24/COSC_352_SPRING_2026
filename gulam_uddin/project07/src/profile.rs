use crate::cli::Args;
use crate::error::ProfilingError;
use crate::infer;
use crate::stats;
use crate::types::{ColumnProfile, ColumnType, FileProfile, TypeVotes};

use std::fs::File;
use std::io::{self, BufReader, Read, Write};
use std::path::Path;

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Profile a CSV file described by `args`.
///
/// The implementation uses **two streaming passes**:
///
/// 1. **Inference pass** — scans every row to vote on each column's type,
///    count nulls, and collect unique values.
/// 2. **Statistics pass** — now that the type is known, streams the file
///    again and feeds each value to the appropriate `Accumulator`.
///
/// Neither pass loads the full file into memory (for file inputs; stdin is
/// spooled to a temp file so that two passes are possible).
pub fn profile_csv(args: &Args) -> Result<FileProfile, ProfilingError> {
    // If input is stdin, spool to a temporary file so we can do two passes.
    let effective_path = maybe_spool_stdin(&args.file)?;
    let file_path = effective_path.as_deref().unwrap_or(&args.file);

    // ---- Pass 1: type inference ----
    let (headers, votes_per_col, row_count, null_counts) =
        inference_pass(file_path, args)?;

    let num_cols = headers.len();
    if num_cols == 0 {
        return Err(ProfilingError::EmptyFile);
    }

    // Decide column types
    let col_types: Vec<ColumnType> = votes_per_col
        .iter()
        .map(|v| infer::infer_column_type(v, args.category_threshold))
        .collect();

    // ---- Pass 2: statistics accumulation ----
    let mut accumulators: Vec<Box<dyn crate::types::Accumulator>> = col_types
        .iter()
        .map(|t| stats::make_accumulator(*t))
        .collect();

    streaming_pass(file_path, args, |_row_idx, fields| {
        for (col_idx, value) in fields.iter().enumerate() {
            if col_idx < num_cols && !infer::is_null(value) {
                accumulators[col_idx].observe(value);
            }
        }
    })?;

    // ---- Build column profiles ----
    let mut columns: Vec<ColumnProfile> = Vec::with_capacity(num_cols);

    for col_idx in 0..num_cols {
        let mut profile = ColumnProfile::new(headers[col_idx].clone());
        profile.inferred_type = col_types[col_idx];
        profile.row_count = row_count;
        profile.null_count = null_counts[col_idx];
        profile.null_percent = if row_count > 0 {
            (null_counts[col_idx] as f64 / row_count as f64) * 100.0
        } else {
            0.0
        };
        profile.unique_count = votes_per_col[col_idx].unique_values.len();

        // Finalize type-specific stats
        accumulators[col_idx].finalize(
            &mut profile,
            args.percentiles,
            args.histogram,
            args.top_n,
        );

        // Mixed-type warning
        if let Some(warning) =
            infer::mixed_type_warning(&votes_per_col[col_idx], col_types[col_idx])
        {
            profile.warnings.push(warning);
        }

        // Constant-column warning
        if profile.unique_count == 1 && row_count > 1 {
            profile
                .warnings
                .push("Constant column: all non-null values are identical".to_string());
        }

        columns.push(profile);
    }

    // Clean up temp file if we created one
    if let Some(ref path) = effective_path {
        let _ = std::fs::remove_file(path);
    }

    Ok(FileProfile {
        file_name: args.file.clone(),
        total_rows: row_count,
        total_columns: num_cols,
        columns,
    })
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// If `path` is `"-"` (stdin), spool all of stdin into a temporary file and
/// return its path. Otherwise return `None`.
fn maybe_spool_stdin(path: &str) -> Result<Option<String>, ProfilingError> {
    if path != "-" {
        return Ok(None);
    }
    let tmp_path = std::env::temp_dir().join("csvprof_stdin.tmp");
    let tmp_str = tmp_path.to_string_lossy().into_owned();
    let mut tmp_file = File::create(&tmp_path)?;
    let mut stdin = io::stdin().lock();
    let mut buf = [0u8; 8192];
    loop {
        let n = stdin.read(&mut buf)?;
        if n == 0 {
            break;
        }
        tmp_file.write_all(&buf[..n])?;
    }
    tmp_file.flush()?;
    Ok(Some(tmp_str))
}

/// Open a CSV reader for `path`.
fn open_reader(path: &str, args: &Args) -> Result<csv::Reader<Box<dyn Read>>, ProfilingError> {
    let p = Path::new(path);
    if !p.exists() {
        return Err(ProfilingError::FileNotFound {
            path: path.to_owned(),
        });
    }
    let reader: Box<dyn Read> = Box::new(BufReader::new(File::open(p)?));

    let csv_reader = csv::ReaderBuilder::new()
        .delimiter(args.delimiter as u8)
        .has_headers(!args.no_header)
        .flexible(true)
        .from_reader(reader);

    Ok(csv_reader)
}

/// First pass: infer types, count rows & nulls.
fn inference_pass(
    path: &str,
    args: &Args,
) -> Result<(Vec<String>, Vec<TypeVotes>, usize, Vec<usize>), ProfilingError> {
    let mut rdr = open_reader(path, args)?;

    // Headers
    let headers: Vec<String> = if args.no_header {
        Vec::new()
    } else {
        rdr.headers()?.iter().map(|h| h.to_owned()).collect()
    };

    let mut votes: Vec<TypeVotes> = Vec::new();
    let mut null_counts: Vec<usize> = Vec::new();
    let mut row_count: usize = 0;
    let mut resolved_headers = headers;

    for result in rdr.records() {
        let record = result?;
        // Lazy-init on first record when no header
        if votes.is_empty() {
            let ncols = record.len();
            votes = vec![TypeVotes::default(); ncols];
            null_counts = vec![0usize; ncols];
            if resolved_headers.is_empty() {
                resolved_headers = (0..ncols).map(|i| format!("col_{i}")).collect();
            }
        }
        row_count += 1;
        for (col_idx, field) in record.iter().enumerate() {
            if col_idx >= votes.len() {
                continue; // ragged row
            }
            let trimmed = field.trim();
            if infer::is_null(trimmed) {
                null_counts[col_idx] += 1;
            } else {
                infer::vote(&mut votes[col_idx], trimmed);
            }
        }
    }

    Ok((resolved_headers, votes, row_count, null_counts))
}

/// Generic streaming pass — calls `on_row` for every record.
fn streaming_pass<F>(path: &str, args: &Args, mut on_row: F) -> Result<(), ProfilingError>
where
    F: FnMut(usize, Vec<&str>),
{
    let mut rdr = open_reader(path, args)?;
    let mut row_idx: usize = 0;
    for result in rdr.records() {
        let record = result?;
        let fields: Vec<&str> = record.iter().map(|f| f.trim()).collect();
        on_row(row_idx, fields);
        row_idx += 1;
    }
    Ok(())
}