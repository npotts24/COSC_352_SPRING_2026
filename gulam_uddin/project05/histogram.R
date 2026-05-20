#!/usr/bin/env Rscript

# Baltimore City Homicide Data Analysis
# This script scrapes homicide data from chamspage.blogspot.com
# and generates a histogram showing distribution by a meaningful statistic

# Load required libraries
library(rvest)
library(dplyr)
library(stringr)
library(lubridate)

# Function to scrape homicide data from a given year
scrape_homicide_data <- function(year) {
  url <- sprintf("https://chamspage.blogspot.com/%d/01/%d-baltimore-city-homicide-list.html", 
                 year, year)
  
  cat(sprintf("Scraping data from %d...\n", year))
  
  tryCatch({
    # Read the webpage
    page <- read_html(url)
    
    # Extract all tables from the page
    tables <- page %>% html_nodes("table") %>% html_table(fill = TRUE)
    
    if (length(tables) == 0) {
      cat(sprintf("Warning: No tables found for year %d\n", year))
      return(NULL)
    }
    
    # Find the largest table (the main homicide list)
    table_sizes <- sapply(tables, nrow)
    main_table_idx <- which.max(table_sizes)
    df <- tables[[main_table_idx]]
    
    # The first row often contains the headers, use it to set column names
    if (nrow(df) > 1) {
      # Check if first row looks like headers
      first_row <- as.character(df[1, ])
      if (any(grepl("No\\.|Date|Name|Age", first_row, ignore.case = TRUE))) {
        # Use first row as column names
        colnames(df) <- first_row
        df <- df[-1, ]  # Remove the header row from data
      }
    }
    
    # Add year column
    df$Year <- year
    
    return(df)
    
  }, error = function(e) {
    cat(sprintf("Error scraping %d: %s\n", year, e$message))
    return(NULL)
  })
}

# Function to clean and standardize the data
clean_homicide_data <- function(df) {
  
  # Print column names to understand structure
  cat("\nColumn names found:\n")
  print(names(df))
  cat(sprintf("\nTotal rows before cleaning: %d\n", nrow(df)))
  
  # Clean column names - remove special characters and standardize
  names(df) <- gsub("\\s+", "_", names(df))
  names(df) <- gsub("[^A-Za-z0-9_]", "", names(df))
  
  # Try to find the date column (could be "Date_Died", "Date", etc.)
  date_col <- names(df)[grep("Date", names(df), ignore.case = TRUE)][1]
  
  # Try to find name column
  name_col <- names(df)[grep("Name", names(df), ignore.case = TRUE)][1]
  
  # Try to find age column  
  age_col <- names(df)[grep("Age", names(df), ignore.case = TRUE)][1]
  
  # Try to find number column
  no_col <- names(df)[grep("No", names(df), ignore.case = TRUE)][1]
  
  # Filter out rows that don't have valid homicide numbers (skip XXX entries and empty rows)
  if (!is.na(no_col)) {
    df <- df[!is.na(df[[no_col]]) & df[[no_col]] != "" & !grepl("XXX|\\?\\?\\?", df[[no_col]]), ]
  }
  
  cat(sprintf("Rows after filtering invalid entries: %d\n", nrow(df)))
  
  # Parse dates if date column exists
  if (!is.na(date_col) && date_col %in% names(df)) {
    cat(sprintf("\nParsing dates from column: %s\n", date_col))
    
    # Try different date formats
    df$Date <- mdy(df[[date_col]])
    
    # If that didn't work, try other formats
    if (all(is.na(df$Date))) {
      df$Date <- parse_date_time(df[[date_col]], orders = c("mdy", "dmy", "ymd"))
    }
    
    # Extract month and day of week
    df$Month <- month(df$Date, label = TRUE, abbr = TRUE)
    df$DayOfWeek <- wday(df$Date, label = TRUE, abbr = TRUE)
    df$MonthNum <- month(df$Date)
    
    # Count valid dates
    valid_dates <- sum(!is.na(df$Date))
    cat(sprintf("Successfully parsed %d dates\n", valid_dates))
  } else {
    cat("Warning: No date column found\n")
  }
  
  # Parse ages if age column exists
  if (!is.na(age_col) && age_col %in% names(df)) {
    # Extract numeric age (remove any non-numeric characters)
    df$Age <- as.numeric(str_extract(df[[age_col]], "\\d+"))
    valid_ages <- sum(!is.na(df$Age))
    cat(sprintf("Successfully parsed %d ages\n", valid_ages))
  }
  
  return(df)
}

# Main execution
cat("Baltimore City Homicide Data Analysis\n")
cat("=====================================\n\n")

# Scrape data from 2025 (and optionally more years for richer analysis)
years_to_scrape <- c(2025, 2024, 2023)  # Add more years as desired
all_data <- list()

for (year in years_to_scrape) {
  data <- scrape_homicide_data(year)
  if (!is.null(data)) {
    all_data[[as.character(year)]] <- data
  }
  # Be polite to the server
  Sys.sleep(1)
}

# Combine all data
if (length(all_data) == 0) {
  stop("Failed to scrape any data. Please check the URL and internet connection.")
}

combined_data <- bind_rows(all_data)
cat(sprintf("\nTotal records scraped: %d\n", nrow(combined_data)))

# Clean the data
cleaned_data <- clean_homicide_data(combined_data)

# Generate histogram based on chosen statistic
# Example: Distribution by Month
cat("\n\nGenerating Histogram: Homicides by Month\n")
cat("==========================================\n\n")

# Count homicides by month
if ("Month" %in% names(cleaned_data)) {
  monthly_counts <- cleaned_data %>%
    filter(!is.na(Month)) %>%
    group_by(Month) %>%
    summarise(Count = n()) %>%
    arrange(Month)
  
  # Print tabular histogram to stdout
  cat("Homicides by Month:\n")
  cat("-------------------\n")
  print(monthly_counts, n = Inf)
  cat("\n")
  
  # Print ASCII histogram for better visualization in terminal
  cat("\nASCII Histogram:\n")
  cat("----------------\n")
  max_count <- max(monthly_counts$Count)
  scale_factor <- 50 / max_count  # Scale to max 50 characters
  
  for (i in 1:nrow(monthly_counts)) {
    month <- as.character(monthly_counts$Month[i])
    count <- monthly_counts$Count[i]
    bar_length <- round(count * scale_factor)
    bar <- paste(rep("█", bar_length), collapse = "")
    cat(sprintf("%-4s | %s %d\n", month, bar, count))
  }
  
} else if ("Age" %in% names(cleaned_data)) {
  # Fallback: Age distribution if date data not available
  cat("Generating histogram by Age instead (date data not available)\n\n")
  
  age_data <- cleaned_data %>%
    filter(!is.na(Age), Age > 0, Age < 100) %>%
    mutate(AgeGroup = cut(Age, 
                          breaks = c(0, 18, 30, 40, 50, 60, 100),
                          labels = c("0-17", "18-29", "30-39", "40-49", "50-59", "60+")))
  
  age_counts <- age_data %>%
    group_by(AgeGroup) %>%
    summarise(Count = n())
  
  cat("Homicides by Age Group:\n")
  cat("-----------------------\n")
  print(age_counts, n = Inf)
  
} else {
  cat("Warning: Could not generate histogram due to data structure issues\n")
  cat("Available columns:\n")
  print(names(cleaned_data))
}

cat("\nAnalysis complete!\n")