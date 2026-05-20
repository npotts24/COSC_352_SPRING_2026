# csvprof

`csvprof` is a streaming command-line CSV profiler written in Rust.

It reads a CSV row by row and produces a structured report describing each column's shape, data quality, and summary statistics without loading the full file into memory.

## Features

- Streaming CSV processing with bounded memory use
- Type inference for `int`, `float`, `bool`, `date`, `categorical`, and `text`
- Null counting and non-null counting
- Exact numeric aggregates in one pass:
  - min
  - max
  - mean
  - standard deviation
- Approximate quantiles with a bounded reservoir sample:
  - median
  - optional percentiles via `--percentiles`
- Distinct counting:
  - exact until a configurable threshold
  - approximate beyond that threshold
- Top value detection with a bounded heavy-hitter sketch
- Human-readable Markdown output and machine-friendly JSON output

## Build

```bash
cargo build --release
```

Run the binary directly:

```bash
./target/release/csvprof path/to/file.csv
```

Or with Cargo:

```bash
cargo run -- path/to/file.csv
```

## Usage

```text
Usage: csvprof [OPTIONS] <FILE>

Arguments:
  <FILE>  Input CSV path. Use `-` to read from stdin

Options:
      --output-format <OUTPUT_FORMAT>
          Output format for the final report
          [default: markdown]
          [possible values: markdown, json]

      --percentiles <PERCENTILES>
          Optional percentile list such as `50,90,95,99`

      --delimiter <DELIMITER>
          CSV delimiter as a single-byte character
          [default: ,]

      --no-headers
          Treat the first row as data instead of headers

      --top-k <TOP_K>
          Number of heavy hitters to print in the report
          [default: 5]

      --top-k-capacity <TOP_K_CAPACITY>
          Capacity for the bounded heavy-hitter sketch
          [default: 32]

      --distinct-capacity <DISTINCT_CAPACITY>
          Capacity for bounded distinct counting. Exact until this threshold, approximate afterwards
          [default: 1024]

      --sample-size <SAMPLE_SIZE>
          Reservoir sample size used for approximate median and opt-in percentiles
          [default: 4096]

      --null-values <NULL_VALUES>
          Additional case-insensitive null markers, comma-separated

  -h, --help
          Print help

  -V, --version
          Print version
```

## Examples

Profile a CSV file:

```bash
csvprof data.csv
```

Read from standard input:

```bash
cat data.csv | csvprof -
```

Request JSON output:

```bash
csvprof data.csv --output-format json
```

Request additional percentiles:

```bash
csvprof data.csv --percentiles 50,90,95,99
```

Use a tab delimiter:

```bash
csvprof data.tsv --delimiter $'\t'
```

Treat the first row as data:

```bash
csvprof data.csv --no-headers
```

Add custom null markers:

```bash
csvprof data.csv --null-values unknown,missing,blank
```

Tune bounded-memory sketches for large files:

```bash
csvprof big.csv --top-k 10 --top-k-capacity 64 --distinct-capacity 4096 --sample-size 8192
```

## Output

The default `markdown` output is optimized for terminal readability and prints one section per column.

Example:

```markdown
# csvprof report

Rows profiled: **95**

## age
- Type: int
- Rows: 95
- Nulls: 1
- Non-null: 94
- Distinct: 44
- Min/Max: 15 / 79
- Mean/Median/Std Dev: 35.053191 / 33.0 / 11.939243
- Top values: 37 (6), 30 (5), 33 (5), 38 (4), 25 (4)
- Percentiles: p90=51.400000
```

The `json` output emits the full report as structured JSON for automation or downstream processing.

## Type Inference

Each non-null value is tested against several parsers during the streaming pass.

Inference order:

1. `Int`
2. `Float`
3. `Bool`
4. `Date`
5. `Categorical`
6. `Text`

Notes:

- Integer columns remain `int` only if every non-null value parses as an integer.
- Mixed integer and decimal values become `float`.
- Mixed numeric and free-text values fall back to `text`.
- Dates are detected from a small set of lightweight formats such as:
  - `2025-04-10`
  - `2025/04/10`
  - `04/10/2025`
  - `04/10/25`
  - `2025-04-10T13:45:00`
  - `11/2014` (normalized to the first day of the month)
- Low-cardinality short string columns are inferred as `categorical`; everything else becomes `text`.

## Streaming Strategy

`csvprof` is intentionally designed to avoid reading the entire dataset into memory.

Per-column state is updated as each row is read:

- Numeric columns:
  - running count
  - running mean
  - running variance accumulator using Welford's algorithm
  - running min/max
- Percentiles and median:
  - bounded reservoir sample
  - approximate for large datasets
- Distinct count:
  - exact set until `--distinct-capacity`
  - KMV-style sketch after that
- Top values:
  - bounded heavy-hitter sketch
  - approximate when the number of unique values exceeds sketch capacity

This gives predictable memory growth relative to the number of columns rather than the number of rows.

## Accuracy Trade-offs

Some metrics are exact, others are approximate by design:

- Exact:
  - row counts
  - null counts
  - min/max
  - mean
  - standard deviation
- Approximate on large data:
  - median
  - user-requested percentiles
  - top-k values when heavy-hitter capacity is exceeded
  - distinct counts after the exact threshold is exceeded

The report includes notes when approximate methods are in use.

## Development

Run tests:

```bash
cargo test
```

Format the code:

```bash
cargo fmt
```
