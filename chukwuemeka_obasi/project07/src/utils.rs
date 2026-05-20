#[derive(Debug, Clone)]
pub enum DataType {
    Integer,
    Float,
    Text,
}

pub fn infer_type(values: &[String]) -> DataType {
    let mut is_int = true;
    let mut is_float = true;

    for v in values {
        if v.trim().is_empty() {
            continue;
        }

        if v.parse::<i64>().is_err() {
            is_int = false;
        }

        if v.parse::<f64>().is_err() {
            is_float = false;
        }
    }

    if is_int {
        DataType::Integer
    } else if is_float {
        DataType::Float
    } else {
        DataType::Text
    }
}