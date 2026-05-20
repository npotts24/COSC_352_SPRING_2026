use chrono::NaiveDate;

/// Date formats we attempt when classifying a value as a date.
static DATE_FORMATS: &[&str] = &[
    "%Y-%m-%d",
    "%m/%d/%Y",
    "%d/%m/%Y",
    "%Y/%m/%d",
    "%d-%m-%Y",
    "%B %d, %Y",
    "%b %d, %Y",
    "%Y%m%d",
];

/// Try to parse a string as an integer (i64).
pub fn try_int(s: &str) -> bool {
    s.trim().parse::<i64>().is_ok()
}

/// Try to parse a string as a float (f64), excluding pure integers
/// so we can distinguish the two types.
pub fn try_float(s: &str) -> bool {
    let t = s.trim();
    // Rust's f64::parse accepts "1" as valid — we want to mark
    // something as float only if it *isn't* a clean integer.
    t.parse::<f64>().is_ok()
}

/// Try to parse a string as a boolean.
pub fn try_bool(s: &str) -> bool {
    matches!(
        s.trim().to_lowercase().as_str(),
        "true" | "false" | "yes" | "no" | "1" | "0" | "t" | "f" | "y" | "n"
    )
}

/// Try to parse a string as a date against known formats.
pub fn try_date(s: &str) -> bool {
    let t = s.trim();
    DATE_FORMATS
        .iter()
        .any(|fmt| NaiveDate::parse_from_str(t, fmt).is_ok())
}

/// Parse as f64 for numeric accumulation (after we know the column is numeric).
pub fn parse_f64(s: &str) -> Option<f64> {
    s.trim().parse::<f64>().ok()
}
