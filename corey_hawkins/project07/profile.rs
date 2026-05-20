use chrono::NaiveDate;

use serde::Serialize;

use std::collections::{HashMap, HashSet};

use std::ops::Range;

// Enum to represent the inferred data type of a column

# [derive(Debug, Clone, PartialEq, Serialize)]

pub enum DataType {

    Integer,

    Float,

    Boolean,

    Date,

    Categorical,

    Text,

    Mixed,

}

// Structure to hold statistics for a column

# [derive(Debug, Clone, Serialize)]

pub struct ColumnStats {

    pub row_count: usize,

    pub null_count: usize,

    pub unique_count: usize,

    pub min_numeric: Option<f64>,

    pub max_numeric: Option<f64>,

    pub mean_numeric: Option<f64>,

    pub median_numeric: Option<f64>,

    pub std_dev_numeric: Option<f64>,

    pub percentiles_numeric: Option<HashMap<String, f64>>, // e.g., {"p5": 10.0, ...}

    pub min_date: Option<NaiveDate>,

    pub max_date: Option<NaiveDate>,

    pub shortest_string_len: Option<usize>,

    pub longest_string_len: Option<usize>,

    pub top_5_freq: Option<Vec<(String, usize)>>,

    pub least_5_freq: Option<Vec<(String, usize)>>,

    pub value_frequency_histogram: Option<HashMap<String, usize>>,

}

impl ColumnStats {

    // helper to create an empty stats object for a new column

    pub fn new() -> Self {

        ColumnStats {

            row_count: 0,

            null_count: 0,

            unique_count: 0,

            min_numeric: None,

            max_numeric: None,

            mean_numeric: None,

            median_numeric: None,

            std_dev_numeric: None,

            percentiles_numeric: None,

            min_date: None,

            max_date: None,

            shortest_string_len: None,

            longest_string_len: None,

            top_5_freq: None,

            least_5_freq: None,

            value_frequency_histogram: None,

        }

    }

    // Method to update stats based on a new value

    pub fn update(&mut self, value: &str, inferred_type: &DataType) {

        self.row_count += 1;

        let is_null = value.is_empty() || value.trim().eq_ignore_ascii_case("null") || value.trim().eq_ignore_ascii_case("na"); // Add more null representations if needed

        if is_null {

            self.null_count += 1;

            return; // Skip statistical updates for nulls

        }

        // Collect unique values for later count and frequency analysis and increment row_count and handle nulls.

        match inferred_type {

            DataType::Integer => {

                if let Ok(num) = value.parse::<i64>() {

                    let f64_num = num as
