use crate::{error::ProfilerError, profile::ColumnProfile};

pub fn emit_json(profiles: &[ColumnProfile]) -> Result<(), ProfilerError> {
    let json = serde_json::to_string_pretty(profiles)?;
    println!("{json}");
    Ok(())
}
