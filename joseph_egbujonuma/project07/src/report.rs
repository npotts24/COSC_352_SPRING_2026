use crate::profiler::CsvProfiler;

pub fn print_report(profiler: &CsvProfiler) {
    let mut profiler = CsvProfiler {
        columns: profiler.columns.clone(),
    };

    profiler.finalize();

    println!("\nCSV PROFILE REPORT");
    println!("==================\n");

    for column in &profiler.columns {
        println!("Column: {}", column.name);
        println!("  Inferred type: {}", column.inferred_type);
        println!("  Row count: {}", column.row_count);
        println!("  Null count: {}", column.null_count);

        let null_pct = if column.row_count > 0 {
            (column.null_count as f64 / column.row_count as f64) * 100.0
        } else {
            0.0
        };
        println!("  Null %: {:.2}%", null_pct);
        println!("  Unique value count: {}", column.unique_count);

        if let Some(min) = column.min {
            println!("  Min: {}", min);
        }
        if let Some(max) = column.max {
            println!("  Max: {}", max);
        }
        if let Some(mean) = column.mean {
            println!("  Mean: {:.2}", mean);
        }

        if let Some(shortest) = column.shortest_len {
            println!("  Shortest string length: {}", shortest);
        }
        if let Some(longest) = column.longest_len {
            println!("  Longest string length: {}", longest);
        }

        let top_values = column.top_values(5);
        if !top_values.is_empty() {
            println!("  Top values:");
            for (value, count) in top_values {
                println!("    {} -> {}", value, count);
            }
        }

        if column.mixed_type_warning {
            println!("  Warning: mixed types detected");
        }
        if column.constant_warning {
            println!("  Warning: constant column");
        }

        println!();
    }
}