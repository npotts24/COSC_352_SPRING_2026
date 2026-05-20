# Data Profiler{csvprof} Design Document

## Overview

`csvprof` is a production-quality CSV data profiling tool written in Rust. It ingests any CSV file (or stdin) and emits a structured, human-readable report describing the shape, quality, and statistical profile of each column.

## Architecture

### Trait-Based Extensibility

The core design is built around the `ColumnProfiler` trait, which abstracts the profiling logic for different column types:

```rust
pub trait ColumnProfiler: Send {
    fn feed(&mut self, value: Option<&str>);
    fn report(&self) -> ColumnReport;
}
```

**Why this design:**
- **Extensibility**: Adding a new column type requires only:
  1. Adding a new `InferredType` variant
  2. Creating a new struct implementing `ColumnProfiler`
  3. Registering it in the `create_profiler()` factory function
  - **No changes** to `main.rs`, report rendering, or streaming logic
- **Type Safety**: Rust's trait system provides compile-time guarantees
- **Separation of Concerns**: Each profiler type is isolated in its own module

**Implementations:**
- `IntegerProfiler` - integer statistics with Welford's online mean/variance
- `FloatProfiler` - floating-point statistics with NaN handling via `ordered-float`
- `BooleanProfiler` - frequency distribution with normalization
- `DateProfiler` - temporal range statistics
- `CategoricalProfiler` - categorical frequency distribution with top/bottom values
- `TextProfiler` - string length statistics

### Type Inference Engine

The `TypeInferrer` struct samples column values and determines the most likely type using a hierarchical approach:

**Inference order:** Boolean → Integer → Float → Date → Categorical/Text

This order reflects:
1. **Boolean** first (most specific)
2. **Numeric types** (Integer → Float, narrowest to widest)
3. **Temporal** (date-parseable strings)
4. **Categorical vs Text** (determined by `--max-unique` threshold)

**Key features:**
- Samples up to 1,000 rows for inference
- Skips null values during sampling
- Detects mixed types: if a column is inferred as Integer but contains unparseable values, a warning is generated

### Streaming Pipeline

The profiling process uses a **two-pass architecture**:

1. **First Pass**: Type Inference
   - Reads input into memory (for stdin compatibility)
   - Samples column values
   - Infers column types

2. **Second Pass**: Profiling
   - Creates typed profilers for each column
   - Streams through rows, feeding each value to the appropriate profiler
   - Values are processed incrementally (no Vec collection)

**Streaming Implementation:**
- Uses the `csv` crate's `Reader` for zero-copy CSV parsing
- Each profiler uses streaming algorithms:
  - **Welford's online algorithm** for mean/variance (O(1) space)
  - **Reservoir sampling** concept applied to percentiles
  - Frequency maps for categorical values
  - Single-pass statistics for text length

**Memory Efficiency:**
- No row buffering in the hot path
- Pre-computed type information minimizes per-row overhead
- Ordered-float wrapping for NaN-safe uniqueness tracking

### Error Handling

Custom error type hierarchy using `thiserror`:

```rust
#[derive(Error, Debug)]
pub enum CsvProfError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("CSV parse error: {0}")]
    Csv(#[from] csv::Error),
    
    #[error("Invalid delimiter: {0}")]
    BadDelimiter(String),
    
    #[error("No columns found in CSV")]
    NoColumns,
    
    #[error("Internal error: {0}")]
    Internal(String),
}
```

- **Automatic conversion**: `#[from]` enables ergonomic error propagation
- **Library code** uses typed errors for granular handling
- **Main code** uses `anyhow::Result` for simplicity

### Report Data Structures

Modular report types:
- `ColumnReport` - aggregates all statistics for a column
- `NumericStats` - mean, median, std_dev, percentiles (conditionally)
- `CategoricalStats` - frequency distribution, histograms
- `TextStats` - min/max/avg length
- `DateStats` - date range
- `CsvReport` - top-level report with file metadata

All structures derive `Serialize` for JSON output support.

### Output Rendering

Two output modes:

**1. Terminal (Default)**
- Uses `comfy-table` for ASCII table rendering
- Summary table: file, row count, column count
- Per-column tables with type-specific statistics
- ANSI formatting ready for warnings (constant columns, mixed types)
- Clean, newspaper-like layout

**2. JSON Mode (`--json`)**
- Serializes entire report via `serde_json`
- Snake_case field names
- Omits null/None fields for compact output
- Parseable with standard JSON tools

## Performance Characteristics

| Aspect | Implementation |
|--------|-----------------|
| **Time Complexity** | O(n) single pass after type inference |
| **Space Complexity** | O(u) where u = unique values in worst case (categorical profiler) |
| **Large Files** | No buffering; streaming prevents OOM on >500MB files |
| **Type Inference** | Fast heuristic sampling (1,000 rows) |

## Tradeoffs

1. **Two-Pass Reading**: 
   - **Pro**: Accurate type inference, clean streaming
   - **Con**: Requires buffering stdin to memory
   - **Choice**: Necessary for correct inference; stdin buffering is reasonable for most use cases

2. **Sampling for Type Inference**:
   - **Pro**: Fast inference for large files
   - **Con**: May miss rare types (e.g., integer column with one text value)
   - **Choice**: Pragmatic balance; warnings catch inconsistencies

3. **Unique Value Tracking**:
   - **Pro**: Accurate unique counts, frequency statistics
   - **Con**: O(u) memory for categorical columns with many unique values
   - **Alternative**: Could implement HyperLogLog for cardinality estimation

4. **No Mutable Streaming**:
   - **Design**: Profilers are fed `Option<&str>` (borrowed values)
   - **Benefit**: Zero-copy by default; cloning only when storage needed
   - **Cost**: HashMap/Vec allocations in individual profilers

## Module Structure

```
src/
├── main.rs           → Orchestration + streaming pipeline
├── cli.rs            → clap argument parsing
├── error.rs          → Error types (CsvProfError)
├── infer.rs          → Type inference engine
├── profiler/
│   ├── mod.rs        → ColumnProfiler trait + factory
│   ├── integer.rs    → IntegerProfiler
│   ├── float.rs      → FloatProfiler
│   ├── boolean.rs    → BooleanProfiler
│   ├── date.rs       → DateProfiler
│   ├── categorical.rs → CategoricalProfiler
│   └── text.rs       → TextProfiler
├── report.rs         → Report data structures
└── output.rs         → Rendering (terminal + JSON)
```

Each profiler module is self-contained and independently testable.

## Adding a New Column Type

To add support for a new inferred type (e.g., `UUID`):

1. **Add to `InferredType` enum** (`infer.rs`):
   ```rust
   pub enum InferredType {
       // ... existing variants ...
       Uuid,
   }
   ```

2. **Create profiler module** (`profiler/uuid.rs`):
   ```rust
   pub struct UuidProfiler { /* ... */ }
   impl ColumnProfiler for UuidProfiler { /* ... */ }
   ```

3. **Register in factory** (`profiler/mod.rs`):
   ```rust
   InferredType::Uuid => Box::new(uuid::UuidProfiler::new(column_name)),
   ```

4. **Update type inference** (`infer.rs`):
   ```rust
   if self.try_uuid(values) {
       return InferredType::Uuid;
   }
   ```

**Result:** No changes needed to main.rs, output modules, or streaming logic.

## Testing

The codebase includes unit tests:
- Type inference (`infer.rs`): Boolean, Integer, Float, Date, Categorical detection
- Numeric statistics: Welford's algorithm verification
- Percentile calculation: Edge case handling

Run tests:
```bash
cargo test
```

## Dependencies

| Crate | Purpose |
|-------|---------|
| `csv` | Zero-copy CSV reading |
| `clap` | CLI with derive macros |
| `serde` + `serde_json` | Serialization/JSON output |
| `chrono` | Date parsing |
| `comfy-table` | Terminal table rendering |
| `ordered-float` | NaN-safe float comparison |
| `anyhow` | Error context propagation |
| `thiserror` | Custom error types |

All dependencies are versioned for stability and security.

## Future Enhancements

1. **Streaming Type Inference**: Use HyperLogLog for cardinality without storing all values
2. **Parallel Processing**: Multi-threaded profiling for very wide CSVs
3. **Custom Date Formats**: User-provided format strings
4. **Column Filtering**: Profile only specified columns
5. **Correlation Matrix**: For numeric columns
6. **Data Quality Scoring**: Automated data quality metrics
