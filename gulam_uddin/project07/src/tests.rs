#[cfg(test)]
mod tests {
    use crate::infer::{self, is_boolean, is_date, is_float, is_integer, is_null};
    use crate::types::{ColumnType, TypeVotes};

    // -----------------------------------------------------------------------
    // Value-level parser tests
    // -----------------------------------------------------------------------

    #[test]
    fn test_is_integer() {
        assert!(is_integer("42"));
        assert!(is_integer("-7"));
        assert!(is_integer("0"));
        assert!(!is_integer("3.14"));
        assert!(!is_integer("abc"));
    }

    #[test]
    fn test_is_float() {
        assert!(is_float("3.14"));
        assert!(is_float("-2.5"));
        assert!(is_float("42")); // integers are valid floats
        assert!(!is_float("abc"));
    }

    #[test]
    fn test_is_boolean() {
        for val in &["true", "false", "True", "False", "YES", "no", "1", "0", "T", "f"] {
            assert!(is_boolean(val), "{val} should be boolean");
        }
        assert!(!is_boolean("maybe"));
        assert!(!is_boolean("2"));
    }

    #[test]
    fn test_is_date() {
        assert!(is_date("2023-01-15"));
        assert!(is_date("01/15/2023"));
        assert!(is_date("2023-01-15T10:30:00"));
        assert!(!is_date("not-a-date"));
        assert!(!is_date("42"));
    }

    #[test]
    fn test_is_null() {
        for val in &["", "NA", "n/a", "null", "None", "NaN", "nil", "missing", "-", "."] {
            assert!(is_null(val), "{val} should be null");
        }
        assert!(!is_null("hello"));
        assert!(!is_null("0"));
    }

    // -----------------------------------------------------------------------
    // Column-level inference tests
    // -----------------------------------------------------------------------

    fn build_votes(values: &[&str]) -> TypeVotes {
        let mut votes = TypeVotes::default();
        for v in values {
            if !is_null(v) {
                infer::vote(&mut votes, v);
            }
        }
        votes
    }

    #[test]
    fn test_infer_integer_column() {
        let votes = build_votes(&["1", "2", "3", "4", "5"]);
        assert_eq!(infer::infer_column_type(&votes, 50), ColumnType::Integer);
    }

    #[test]
    fn test_infer_float_column() {
        let votes = build_votes(&["1.1", "2.2", "3.3", "4.4", "5.5"]);
        assert_eq!(infer::infer_column_type(&votes, 50), ColumnType::Float);
    }

    #[test]
    fn test_infer_boolean_column() {
        let votes = build_votes(&["true", "false", "true", "false", "true"]);
        assert_eq!(infer::infer_column_type(&votes, 50), ColumnType::Boolean);
    }

    #[test]
    fn test_infer_date_column() {
        let votes = build_votes(&["2023-01-01", "2023-02-15", "2023-03-20"]);
        assert_eq!(infer::infer_column_type(&votes, 50), ColumnType::Date);
    }

    #[test]
    fn test_infer_categorical_column() {
        let votes = build_votes(&["red", "blue", "green", "red", "blue"]);
        assert_eq!(infer::infer_column_type(&votes, 50), ColumnType::Categorical);
    }

    #[test]
    fn test_infer_text_column_high_cardinality() {
        // Each value is unique — exceeds category threshold of 3
        let votes = build_votes(&["alpha", "bravo", "charlie", "delta"]);
        assert_eq!(infer::infer_column_type(&votes, 3), ColumnType::Text);
    }

    #[test]
    fn test_infer_with_nulls() {
        let votes = build_votes(&["1", "2", "NA", "", "5"]);
        assert_eq!(infer::infer_column_type(&votes, 50), ColumnType::Integer);
    }

    #[test]
    fn test_mixed_type_warning() {
        // Mix of integers and dates
        let votes = build_votes(&[
            "1", "2", "3", "2023-01-01", "2023-02-01", "4", "5", "6", "7", "8",
        ]);
        let inferred = infer::infer_column_type(&votes, 50);
        let warning = infer::mixed_type_warning(&votes, inferred);
        assert!(warning.is_some(), "Should detect mixed types");
    }

    #[test]
    fn test_empty_column_infers_text() {
        let votes = TypeVotes::default();
        assert_eq!(infer::infer_column_type(&votes, 50), ColumnType::Text);
    }

    // -----------------------------------------------------------------------
    // Accumulator tests
    // -----------------------------------------------------------------------

    use crate::stats;
    use crate::types::ColumnProfile;

    #[test]
    fn test_numeric_accumulator() {
        let mut acc = stats::make_accumulator(ColumnType::Integer);
        for v in &["10", "20", "30", "40", "50"] {
            acc.observe(v);
        }
        let mut profile = ColumnProfile::new("test".into());
        acc.finalize(&mut profile, true, false, 5);

        assert_eq!(profile.min_numeric, Some(10.0));
        assert_eq!(profile.max_numeric, Some(50.0));
        assert_eq!(profile.mean, Some(30.0));
        assert_eq!(profile.median, Some(30.0));
        assert!(profile.p25.is_some());
        assert!(profile.p75.is_some());
    }

    #[test]
    fn test_text_accumulator() {
        let mut acc = stats::make_accumulator(ColumnType::Text);
        acc.observe("hi");
        acc.observe("hello");
        acc.observe("hey there, world!");
        let mut profile = ColumnProfile::new("test".into());
        acc.finalize(&mut profile, false, false, 5);

        assert_eq!(profile.shortest_length, Some(2));
        assert_eq!(profile.longest_length, Some(17));
    }

    #[test]
    fn test_categorical_accumulator_top_values() {
        let mut acc = stats::make_accumulator(ColumnType::Categorical);
        for v in &["a", "b", "a", "a", "c", "b"] {
            acc.observe(v);
        }
        let mut profile = ColumnProfile::new("test".into());
        acc.finalize(&mut profile, false, false, 5);

        let top = profile.top_values.unwrap();
        assert_eq!(top[0].0, "a");
        assert_eq!(top[0].1, 3);
    }

    #[test]
    fn test_boolean_accumulator() {
        let mut acc = stats::make_accumulator(ColumnType::Boolean);
        for v in &["true", "false", "true", "true"] {
            acc.observe(v);
        }
        let mut profile = ColumnProfile::new("test".into());
        acc.finalize(&mut profile, false, true, 5);

        assert!(profile.top_values.is_some());
        assert!(profile.histogram.is_some());
    }

    #[test]
    fn test_date_accumulator() {
        let mut acc = stats::make_accumulator(ColumnType::Date);
        acc.observe("2023-01-01");
        acc.observe("2023-06-15");
        acc.observe("2023-12-31");
        let mut profile = ColumnProfile::new("test".into());
        acc.finalize(&mut profile, false, false, 5);

        assert_eq!(profile.min_date.as_deref(), Some("2023-01-01"));
        assert_eq!(profile.max_date.as_deref(), Some("2023-12-31"));
    }
}