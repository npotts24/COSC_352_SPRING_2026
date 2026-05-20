# Data Profiler{csvprof} Quick Start Guide

A production-quality CSV data profiling tool written in Rust.

## Installation & Building

```bash
cd csvprof
cargo build --release
```

The binary will be at `target/release/csvprof`.

## Basic Usage

### Profile a file (human-readable tables)
```bash
./target/release/csvprof data.csv
```

### Profile from stdin
```bash
cat data.csv | ./target/release/csvprof -
```

### JSON output
```bash
./target/release/csvprof data.csv --json
```

### Show percentiles (p5, p25, p75, p95)
```bash
./target/release/csvprof data.csv --percentiles
```

### Write report to file
```bash
./target/release/csvprof data.csv -o report.txt
```

### Custom delimiter
```bash
./target/release/csvprof data.tsv --delimiter $'\t'
```

### Show histograms for categorical columns
```bash
./target/release/csvprof data.csv --hist
```

### Treat first row as data (no header)
```bash
./target/release/csvprof data.csv --no-header
```

## CLI Options

```
USAGE:
    csvprof [OPTIONS] <FILE>

ARGUMENTS:
    <FILE>    Path to CSV file (use "-" for stdin)

OPTIONS:
    -d, --delimiter <CHAR>      Field delimiter [default: ,]
    -n, --no-header             Treat first row as data, not header
    --percentiles               Include p5/p25/p75/p95 in numeric stats
    --top-n <N>                 Top/bottom N frequent values [default: 5]
    --hist                      Show value frequency histogram (categorical)
    --json                      Emit report as JSON instead of tables
    --max-unique <N>            Max unique threshold for categorical [default: 50]
    -o, --output <FILE>         Write report to file instead of stdout
    -h, --help                  Print help
```

## Output Descriptions

### Column Types Detected

- **Integer**: Whole numbers only
- **Float**: Decimal numbers
- **Boolean**: true/false, yes/no, 0/1
- **Date**: Common date formats (YYYY-MM-DD, MM/DD/YYYY, etc.)
- **Categorical**: Discrete values with limited unique count (< max-unique)
- **Text**: Free-form text or high cardinality strings

### Common Statistics

All columns include:
- **Row Count**: Total rows processed
- **Null Count**: Empty/missing values
- **Null %**: Percentage of null values
- **Unique Count**: Distinct non-null values
- **Constant Warning**: Appears if all non-null values are identical
- **Mixed Type Warning**: Appears if type inference detected inconsistency

### Type-Specific Statistics

**Numeric (Integer/Float)**:
- Min, Max, Mean, Median, Std Dev
- P5, P25, P75, P95 (with --percentiles)

**Date**:
- Min/Max dates
- Unique date count

**Categorical/Boolean**:
- Top N frequent values with counts/percentages
- Bottom N least frequent values (optional)
- Histogram visualization (with --hist)

**Text**:
- Min/Max/Average string length

## Example Output

```
────────────────────────────────────────────────────────────────
 File                          Rows                    Columns   
════════════════════════════════════════════════════════════════
 data.csv                      1000                    15        
────────────────────────────────────────────────────────────────

────────────────────────────────────────────────────────────────
 age (Integer)                                                  
════════════════════════════════════════════════════════════════
 Row Count                                      1000            
 Null Count                                     5               
 Null %                                         0.50%           
 Unique Count                                   52              
 Min                                            18.000000       
 Max                                            95.000000       
 Mean                                           45.320000       
 Median                                         44.000000       
 Std Dev                                        17.520000       
 P5                                             21.000000       
 P25                                            33.000000       
 P75                                            57.000000       
 P95                                            79.000000       
────────────────────────────────────────────────────────────────
```

## Design Highlights

- **Streaming Architecture**: Processes large files without OOM (no buffering in hot path)
- **Trait-Based Extensibility**: Add new column types with minimal code changes
- **Type Inference**: Sophisticated sampling-based inference with consistency checking
- **Zero Warnings**: Clean Rust code with `cargo clippy -- -D warnings`
- **Production Quality**: Error handling, comprehensive documentation, unit tests

See [DESIGN.md](DESIGN.md) for architectural details.

## Testing

Run included tests:
```bash
cargo test
```

Test files in root:
- `sample.csv` - Basic example
- `constant_test.csv` - Demonstrates constant column warnings
- `comprehensive_test.csv` - Extended test cases
