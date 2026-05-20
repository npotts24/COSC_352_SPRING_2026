use clap::Parser;

use std::error::Error;

use std::fs::File;

use std::path::PathBuf;

use std::io::{BufReader, Result as IoResult};



# [derive(Debug)]

pub enum CustomError {

    Io(std::io::Error),

    Csv(csv::Error),

    ParseError(String),

    MissingColumn(String),

}

impl std::fmt::Display for CustomError {

    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {

        match self {

            CustomError::Io(err) => write!(f, "IO Error: {}", err),

            CustomError::Csv(err) => write!(f, "CSV Error: {}", err),

            CustomError::ParseError(msg) => write!(f, "Parse Error: {}", msg),

            CustomError::MissingColumn(col) => write!(f, "Missing Column: {}", col),

        }

    }

}

impl Error for CustomError {

    fn source(&self) -> Option<&(dyn Error + 'static)> {

        match self {

            CustomError::Io(err) => Some(err),

            CustomError::Csv(err) => Some(err),

            _ => None,

        }

    }

}

impl From<std::io::Error> for CustomError {

    fn from(err: std::io::Error) -> Self {

        CustomError::Io(err)

    }

}

impl From<csv::Error> for CustomError {

    fn from(err: csv::Error) -> Self {

        CustomError::Csv(err)

    }

}



# [derive(Debug, Clone)]

pub struct ServiceRequest {

    pub request_type: String,

    pub latitude: Option<f64>,

    pub longitude: Option<f64>,

    pub created_date: String, // Keeping as string for simplicity, could parse if needed

}



# [derive(Debug, Clone)]

pub struct School {

    pub school_name: String,

    pub latitude: Option<f64>,

    pub longitude: Option<f64>,

}





pub struct StreamingReader<R: std::io::Read> {

    reader: csv::Reader<R>,

  

    

}

impl<R: std::io::Read> StreamingReader<R> {

    pub fn new(reader: R) -> Result<Self, CustomError> {

        let mut csv_reader = csv::ReaderBuilder::new
