use std::fs::File;
use std::io::{self, BufReader, Read};
use std::path::Path;

use anyhow::Context;
use clap::Parser;

use csvprof::cli::Cli;
use csvprof::profiler::Profiler;
use csvprof::report;

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let config = cli.profiler_config()?;
    let mut profiler = Profiler::new(config);

    let reader = open_input(&cli.file).with_context(|| {
        format!(
            "failed to open input `{}`",
            cli.file.as_os_str().to_string_lossy()
        )
    })?;
    profiler.profile_reader(reader)?;

    let dataset = profiler.finalize();
    let rendered = report::render(&dataset, cli.output_format)?;
    println!("{rendered}");
    Ok(())
}

fn open_input(path: &Path) -> anyhow::Result<Box<dyn Read>> {
    if path == Path::new("-") {
        Ok(Box::new(io::stdin()))
    } else {
        let file = File::open(path)?;
        Ok(Box::new(BufReader::new(file)))
    }
}
