use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "csvprof")]
pub struct Args {
    pub file: String,

    #[arg(long)]
    pub percentiles: bool,

    #[arg(long)]
    pub histogram: bool,
}