CSV Profiling CLI Tool (Rust)
Overview
This project is a command-line CSV profiling tool written in Rust. It analyzes any CSV file and produces a structured, human readable report describing the data’s structure, quality, and statistical properties.

The tool is designed to demonstrate idiomatic Rust concepts such as ownership, error handling, and efficient data processing while handling CSV data in a streaming manner.

Features
Accepts CSV file input via CLI

Automatically infers column data types:

Integer

Float

Boolean

Text

Mixed

Computes per-column statistics:

Row count

Null count and percentage

Unique values

Min / Max

Mean

Median

Standard deviation

Optional advanced metrics:

Percentiles (p5, p25, p75, p95)

Histogram (text-based)

Data quality checks:

Missing values

Constant columns

Low-cardinality categorical detection

Mixed-type warnings

Streams data row-by-row (does not load entire file into memory)



Sample Output
Column: age
Type: Integer
Rows: 5
Nulls: 1 (20.00%)
Unique: 3
Min: 20
Max: 22
Mean: 20.75
Median: 20.5
Std Dev: 0.82
P5: 20
P25: 20
P75: 22
P95: 22
Top values:
  20: 2
  21: 1
  22: 1
Histogram:
20: **
21: *
22: *


Design Highlights
Uses Rust enums for type inference

Modular design separating CLI, logic, and statistics

Efficient streaming approach using CSV reader

HashMap and HashSet for frequency and uniqueness tracking

Error handling using Result and Box<dyn Error>

Author: Rochak Ghimire