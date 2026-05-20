# Project 7: CSV Profiling CLI Tool

## Overview
A command-line data profiling tool written in Rust that analyzes CSV files and produces comprehensive statistical reports.

## Features
- ✅ Automatic column type inference (Integer, Float, Boolean, Date, Categorical, Text)
- ✅ Statistical analysis (mean, median, std dev, min/max)
- ✅ Data quality detection (nulls, outliers, mixed types, constant columns)
- ✅ Stream-based processing for large files
- ✅ Colorized terminal output
- ✅ Support for stdin input

## Requirements
- Rust 1.70+
- Cargo

## Installation

```bash
cd project07
cargo build --release
```

## Usage

### Basic usage:
```bash
cargo run -- sample.csv
```

### From stdin:
```bash
cat sample.csv | cargo run -- -
```

### With compiled binary:
```bash
./target/release/csvprof sample.csv
```

## Command-Line Options

```
csvprof [OPTIONS] <FILE>

Arguments:
  <FILE>  Path to input CSV file (use '-' for stdin)

Options:
  -p, --percentiles  Show percentile statistics (p5, p25, p75, p95)
  -h, --histogram    Display value frequency histograms
  --help             Print help
```

## Output Format

The tool generates a detailed report for each column including:

- **Inferred Type**: Automatically detected data type
- **Row Count**: Total number of rows
- **Null Count/Percentage**: Missing value analysis
- **Unique Values**: Cardinality measurement
- **Statistical Measures**: Mean, median, standard deviation (for numeric columns)
- **String Analysis**: Min/max length (for text columns)
- **Top Values**: Most frequent values with counts
- **Quality Warnings**: Mixed types, constant columns

## Example Output

```
==================================================
CSV PROFILING REPORT
==================================================
Total Columns: 8
Total Rows: 20

┌─────────┐
│ name    │
├─────────┼──────────────────┐
│ Field   │ Value            │
│ Type    │ Text             │
│ Rows    │ 20               │
│ Nulls   │ 0 (0.00%)        │
│ Unique  │ 20               │
└─────────┴──────────────────┘
```

## Design Patterns

### Rust Design Principles Demonstrated:

1. **Ownership & Borrowing**: Efficient memory management without GC
2. **Traits**: `ColumnType` enum with type-specific behavior
3. **Error Handling**: `Result<T, E>` pattern throughout
4. **Zero-Cost Abstractions**: Iterator chains for data processing
5. **Pattern Matching**: Type inference and statistics calculation
6. **Streaming**: Row-by-row CSV processing to handle large files

## Dependencies

- `clap` - Command-line argument parsing
- `csv` - Fast CSV reading/writing
- `colored` - Terminal color output
- `comfy-table` - Beautiful table formatting
- `chrono` - Date/time handling
- `serde` - Serialization framework

## Project Structure

```
project07/
├── Cargo.toml          # Project dependencies
├── src/
│   └── main.rs         # Main implementation
├── sample.csv          # Test data
└── README.md           # This file
```

## Testing

Test with the included sample data:

```bash
cargo run -- sample.csv
```

## Author
Karl Agli - COSC 352 Spring 2026

## License
MIT
