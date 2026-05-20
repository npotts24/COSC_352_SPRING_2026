#[derive(Debug, Clone, PartialEq)]
pub enum DataType {
    Integer,
    Float,
    Boolean,
    Text,
}

impl std::fmt::Display for DataType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let label = match self {
            DataType::Integer => "Integer",
            DataType::Float => "Float",
            DataType::Boolean => "Boolean",
            DataType::Text => "Text",
        };
        write!(f, "{label}")
    }
}