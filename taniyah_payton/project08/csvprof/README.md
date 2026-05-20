# csvprof — Fast Streaming CSV Data Profiler

A command-line data profiling tool written in idiomatic Rust. Accepts any CSV file and
produces a rich, structured report describing the shape, quality, and statistical
characteristics of each column — all streamed row-by-row without loading the file into memory.

---

## Features

| Capability | Details |
|---|---|
| **Type Inference** | Integer, Float, Boolean, Date, Categorical, Text |
| **Null handling** | Recognizes `""`, `null`, `na`, `n/a`, `nan`, `none`, `nil`, `#n/a` |
| **Numeric stats** | Min, Max, Mean, Median, Std Dev, IQR-based outlier count |
| **Percentiles** | P5 / P25 / P75 / P95 (opt-in via `--percentiles`) |
| **Date range** | Min/Max date across 8 common date formats |
| **Categorical** | Top-5 most / least frequent values, optional histogram |
| **Boolean** | True/False counts + top frequency breakdown |
| **Text** | Min/Max/Avg string length |
| **Warnings** | Constant column · Mixed types · High null rate · Low cardinality |
| **JSON output** | Machine-readable structured JSON via `--format json` |
| **Stdin support** | Pipe data via `-` as the filename |
| **Column filter** | Profile only selected columns via `--columns` |

---

## Usage

```
csvprof [OPTIONS] <FILE>

Arguments:
  <FILE>    Path to input CSV file (use `-` for stdin)

Options:
  -f, --format <FORMAT>      Output format: human (default) or json
  -p, --percentiles          Include P5/P25/P75/P95 percentiles for numeric columns
  -H, --histogram            Include full value-frequency histogram for categorical columns
  -c, --columns <COLUMNS>    Only profile these columns (comma-separated names)
  -h, --help                 Print help
  -V, --version              Print version
```

### Examples

```bash
# Basic profiling of all columns
csvprof data.csv

# Percentiles + filter to specific columns
csvprof data.csv --percentiles --columns age,salary,score

# Categorical histogram
csvprof data.csv --histogram --columns department,status

# Read from stdin
cat data.csv | csvprof -

# Emit structured JSON
csvprof data.csv --format json > profile.json

# Combine all flags
csvprof data.csv -p -H -f json -c salary,department > report.json
```

---

## Building from Source

Requires Rust 1.75+ and Cargo.

```bash
cargo build --release
./target/release/csvprof --help
```

---

## Architecture

The codebase is deliberately decomposed into single-responsibility modules:

```
src/
├── main.rs          — CLI (clap) + orchestration pipeline
├── error.rs         — Typed errors via thiserror
├── types.rs         — ColumnType enum + type inference logic
├── ingest.rs        — Streaming CSV reader (csv crate)
├── stats.rs         — Pure statistical functions (mean, std_dev, percentile, IQR)
├── profile.rs       — ColumnProfile struct + Profiler trait + Warning types
├── profilers.rs     — DispatchProfiler: routes each column to its typed analyser
├── report.rs        — Terminal renderer (comfy-table + colored)
└── output_json.rs   — JSON serializer (serde_json)
```

### Design Patterns

- **Trait abstraction (`Profiler`)**: Any new analyser just implements `profile()`. The
  dispatch loop in `main.rs` doesn't change.
- **Enum-discriminated payloads (`TypeStats`)**: Each column type carries its own
  statistics struct. Serde serializes these with a `"kind"` tag for clean JSON.
- **Zero-copy ingestion**: The `csv` crate reads field-by-field into owned `String` values
  per column. No full-file buffering.
- **`thiserror` error chain**: All error variants are typed, not stringly-typed. `anyhow`
  wraps them at the top level for ergonomic `?` propagation.
- **Pure functions in `stats.rs`**: Statistical routines take plain `&[f64]` slices and
  return `Option<f64>` — easily testable in isolation.

---

## Warning Taxonomy

| Warning | Trigger Condition |
|---|---|
| `ConstantColumn` | Only one distinct non-null value in the column |
| `MixedTypes` | Non-null values parse as 2+ incompatible types |
| `HighNullRate` | ≥ 50% of rows are null |
| `LowCardinality` | ≤ 3 distinct values in a Categorical column |
