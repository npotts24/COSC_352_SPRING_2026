# csvprof — CSV Profiling CLI Tool

A command-line data profiling tool written in idiomatic Rust that ingests any CSV file and produces a structured report describing the shape, quality, and statistical characteristics of each column.

## Features

- **Automatic type inference** — detects integer, float, boolean, date, categorical, and text columns (85% threshold voting system)
- **Per-column statistics** — appropriate to each inferred type (numeric stats, date ranges, string lengths, frequency tables)
- **Data quality warnings** — nulls, outliers (IQR method), low-cardinality categoricals, mixed types, constant columns
- **Streaming architecture** — two-pass design that never loads the entire file into memory
- **Multiple output formats** — human-readable terminal tables or machine-readable JSON
- **Stdin support** — pipe data directly with `-`

## Build & Run

```bash
cargo build --release
# The binary is at target/release/csvprof
```

## Usage

```
csvprof [OPTIONS] <FILE>

Arguments:
  <FILE>  Path to input CSV file (use `-` for stdin)

Options:
  -d, --delimiter <DELIMITER>                    Delimiter character [default: ,]
  -p, --percentiles                              Show p5/p25/p75/p95 for numeric columns
      --histogram                                Show full frequency histogram for categoricals
  -f, --format <FORMAT>                          Output format: table or json [default: table]
      --category-threshold <CATEGORY_THRESHOLD>  Max unique values for categorical [default: 50]
      --top-n <TOP_N>                            Number of top/bottom frequent values [default: 5]
      --no-header                                First row is data, not a header
  -h, --help                                     Print help
  -V, --version                                  Print version
```

### Examples

```bash
# Basic profiling
csvprof sample.csv

# With percentiles and histograms
csvprof -p --histogram sample.csv

# JSON output
csvprof -f json data.csv

# Tab-separated, piped from stdin
cat data.tsv | csvprof -d $'\t' -

# Custom category threshold
csvprof --category-threshold 100 large_data.csv
```

## Architecture & Design Patterns

### Trait-based extensibility (`Accumulator`)

The core abstraction is the `Accumulator` trait in `types.rs`:

```rust
pub trait Accumulator: Send {
    fn observe(&mut self, value: &str);
    fn finalize(&mut self, profile: &mut ColumnProfile, ...);
}
```

Each column type has its own accumulator (`NumericAccumulator`, `BooleanAccumulator`, `DateAccumulator`, `CategoricalAccumulator`, `TextAccumulator`). Adding a new inferred type requires:

1. Adding a variant to `ColumnType`
2. Implementing `Accumulator` for the new stats struct
3. Adding a branch to `make_accumulator()` and `infer_column_type()`

### Two-pass streaming

The profiler never loads the full CSV into memory:

- **Pass 1 (inference):** streams rows, voting on each column's type and counting nulls/uniques.
- **Pass 2 (statistics):** streams rows again, dispatching values to the correct `Accumulator`.

### Ownership & error handling

- All errors flow through `ProfilingError` (a `thiserror`-derived enum), making the `?` operator work seamlessly across I/O, CSV parsing, and JSON serialisation.
- The `Accumulator` trait objects are stored as `Box<dyn Accumulator>`, demonstrating dynamic dispatch.
- Data structures use owned `String`s with no lifetime parameters to keep the API surface simple.

## Per-Column Report Fields

| Field | Applicable Types |
|---|---|
| Inferred type | All |
| Row count / null count / null % | All |
| Unique value count | All |
| Min / Max | Numeric, Date |
| Mean / Median / Std dev | Numeric |
| Percentiles (p5/p25/p75/p95) | Numeric (opt-in `-p`) |
| Top-5 most / least frequent values | Categorical, Boolean |
| Value frequency histogram | Categorical (opt-in `--histogram`) |
| Shortest / longest string length | Text |
| Mixed-type warning | All |
| Constant column warning | All |
| Outlier warning (IQR) | Numeric |
| Low cardinality warning | Categorical |

## Project Structure

```
src/
├── main.rs      — entry point and orchestration
├── cli.rs       — command-line argument definitions (clap derive)
├── error.rs     — unified error type (thiserror)
├── types.rs     — ColumnType, ColumnProfile, FileProfile, Accumulator trait
├── infer.rs     — value parsers, type voting, mixed-type detection
├── stats.rs     — Accumulator implementations (Numeric, Boolean, Date, etc.)
├── profile.rs   — two-pass streaming profiling engine
└── report.rs    — table and JSON renderers
```

## Dependencies

| Crate | Purpose |
|---|---|
| `clap` | CLI argument parsing (derive macro) |
| `csv` | Streaming CSV reader |
| `serde` / `serde_json` | JSON serialisation |
| `chrono` | Date parsing |
| `thiserror` | Ergonomic error types |
| `comfy-table` | Terminal table rendering |
| `indexmap` | Insertion-ordered maps |
| `ordered-float` | Sortable floats for percentile computation |

## License

MIT