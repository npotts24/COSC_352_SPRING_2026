use std::env;
use std::error::Error;
use csv::Reader;

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        println!("Usage: csvprof <file.csv>");
        return Ok(());
    }

    let file_path = &args[1];

    let mut rdr = Reader::from_path(file_path)?;

    let headers = rdr.headers()?.clone();

    let mut row_count = 0;

    for result in rdr.records() {
        let _record = result?;
        row_count += 1;
    }

    println!("=== CSV PROFILE REPORT ===");
    println!("Total Rows: {}", row_count);
    println!("Columns:");

    for header in headers.iter() {
        println!(" - {}", header);
    }

    Ok(())
}
