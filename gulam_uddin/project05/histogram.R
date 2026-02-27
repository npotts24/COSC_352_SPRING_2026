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
    
    # Extract the table (adjust selector based on actual HTML structure)
    # The blog typically uses simple HTML tables
    tables <- page %>% html_nodes("table") %>% html_table(fill = TRUE)
    
    if (length(tables) == 0) {
      cat(sprintf("Warning: No tables found for year %d\n", year))
      return(NULL)
    }
    
    # Get the main homicide table (usually the first or largest table)
    df <- tables[[1]]
    
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
  
  # Common cleaning steps (adjust based on actual data structure)
  # The blog format may vary by year, so we need to handle variations
  
  # Try to identify date column (could be "Date", "Date of Death", etc.)
  date_col <- names(df)[grep("date|Date", names(df), ignore.case = TRUE)][1]
  
  if (!is.na(date_col)) {
    # Parse dates - handle various formats
    df$Date <- mdy(df[[date_col]])
    
    # Extract month and day of week
    df$Month <- month(df$Date, label = TRUE)
    df$DayOfWeek <- wday(df$Date, label = TRUE)
  }
  
  # Try to identify age column
  age_col <- names(df)[grep("age|Age", names(df), ignore.case = TRUE)][1]
  
  if (!is.na(age_col)) {
    # Extract numeric age (remove any non-numeric characters)
    df$Age <- as.numeric(str_extract(df[[age_col]], "\\d+"))
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
