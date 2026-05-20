# csvprof — Streaming CSV Data Profiler

A fast, idiomatic Rust CLI that ingests any CSV file and produces a structured
report describing the **shape**, **quality**, and **statistical characteristics**
of every column — without loading the entire file into memory.

---

## Build

```bash
# Requires Rust 1.75+
cargo build --release
# Binary at: target/release/csvprof
```

---

## Usage

```
csvprof [OPTIONS] <FILE>

Arguments:
  <FILE>   Path to input CSV file (use `-` for stdin)

Options:
  -j, --json                          Emit JSON instead of human-readable tables
      --no-color                      Disable ANSI colour output
  -p, --percentiles                   Show p5/p25/p75/p95 for numeric columns
  -H, --histogram                     Show value-frequency histogram for categoricals
      --categorical-threshold <RATIO> Cardinality ratio for Categorical inference [default: 0.10]
      --reservoir <N>                 Reservoir size for percentile approximation [default: 10000]
      --delimiter <CHAR>              CSV field delimiter [default: ,]
  -h, --help                          Print help
  -V, --version                       Print version
```

---

## Examples

```bash
# Basic profiling
csvprof data.csv

# With percentiles and histogram
csvprof data.csv -p -H

# JSON output (pipe to jq, save to file, etc.)
csvprof data.csv -j | jq '.[].name'

# Tab-delimited file
csvprof data.tsv --delimiter $'\t'

# Stdin
cat data.csv | csvprof -
```

---

## Per-Column Report Fields

| Field | Applicable Types |
|---|---|
| Inferred type | All |
| Row count / Null count / Null % | All |
| Unique value count | All |
| Min / Max | Numeric, Date |
| Mean / Median / Std dev | Numeric |
| p5 / p25 / p75 / p95 | Numeric (opt-in `-p`) |
| Top-5 most / least frequent | Categorical, Boolean |
| Value frequency histogram | Categorical (opt-in `-H`) |
| Shortest / Longest string length | Text |
| Mixed-type warning | All |
| Constant column warning | All |
| High null rate warning | All |
| Outlier detection (IQR) | Numeric |

---

## Architecture

```
src/
├── main.rs       — CLI parsing (clap derive), entry point
├── error.rs      — Typed errors via thiserror
├── types.rs      — ColumnType enum + TypeVotes inference engine
├── stats.rs      — OnlineStats (Welford), FrequencyCounter, ColumnAccumulator
├── profiler.rs   — DataSource trait, CsvSource<R>, Profiler
└── report.rs     — ReportRenderer (human tables + JSON)
```

### Design Highlights

- **Trait-based data source** (`DataSource`) — swap in any `Read` source (file,
  stdin, network) without changing profiling logic.
- **Welford's online algorithm** — exact mean/variance in a single pass, O(1)
  memory regardless of file size.
- **Reservoir sampling** — O(k) memory approximate percentiles via random
  replacement (k = `--reservoir`, default 10 000).
- **UniqueTracker** — capped `HashSet` prevents unbounded memory on high-
  cardinality columns; reports "`≥`" when cap is exceeded.
- **TypeVotes** — accumulates per-type parse counts during the streaming pass;
  resolves to the most specific type after the pass completes.
- **Zero second pass** — the entire profile is built in one read of the file.