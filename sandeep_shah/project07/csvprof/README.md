CSV Profiling CLI Tool (csvprof)

A high-performance command-line data profiling tool written in Rust that analyzes CSV files and generates a structured report describing the shape, quality, and statistical characteristics of each column.

🚀 Features
📁 Accepts CSV file input or stdin
🔍 Automatically infers column data types:
Integer
Float
Boolean
Date
Categorical
Text
📊 Computes per-column statistics:
Row count
Null count & percentage
Unique values
📈 Numeric analysis:
Min, Max
Mean, Median
Standard deviation
Outlier detection (IQR method)
📅 Date analysis:
Min and Max date
🔤 Text analysis:
Shortest and longest string length
📦 Categorical analysis:
Top 5 most frequent values
Top 5 least frequent values
⚠️ Data quality checks:
Null values
Mixed-type columns
Constant column detection
⚙️ Optional features:
Percentiles (p5, p25, p75, p95)
Histogram for categorical values
🧾 Output formats:
Human-readable text
JSON


Streaming Design

The tool processes CSV files row-by-row using the csv crate, avoiding loading the entire dataset into memory. This makes it scalable for large datasets.

🔹 Extensibility
Output formatting uses a trait-based design
Easy to add new formats (e.g., HTML, tables)
Type inference and statistics are separated from I/O logic


Author: Sandeep Shah