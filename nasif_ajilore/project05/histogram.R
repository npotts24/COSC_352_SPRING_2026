#!/usr/bin/env Rscript

# Baltimore City Homicide Data Analysis
# Scrapes data from https://chamspage.blogspot.com/
# Creates visualization and analysis of Baltimore homicides

library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)
library(lubridate)

# Set output width for better console display
options(width = 120)

# ============================================================================
# CONFIGURATION
# ============================================================================

# Blog URL patterns
BASE_URL <- "https://chamspage.blogspot.com"
URLS <- list(
  "2025" = paste0(BASE_URL, "/2025/01/2025-baltimore-city-homicide-list.html"),
  "2024" = paste0(BASE_URL, "/2024/01/2024-baltimore-city-homicide-list.html"),
  "2023" = paste0(BASE_URL, "/2023/01/2023-baltimore-city-homicide-list.html")
)

# ============================================================================
# SCRAPING FUNCTIONS
# ============================================================================

#' Scrape homicide data from a single blog post
#' @param url The URL to scrape
#' @param year The year for reference
scrape_homicide_data <- function(url, year) {
  tryCatch({
    cat(sprintf("[%s] Attempting to scrape: %s\n", year, url))
    
    # Read the page
    page <- read_html(url)
    
    # Find all tables on the page
    tables <- page %>% html_table(fill = TRUE)
    
    if (length(tables) == 0) {
      cat(sprintf("[ERROR] No tables found on page for %s\n", year))
      return(NULL)
    }
    
    cat(sprintf("[%s] Found %d tables\n", year, length(tables)))
    
    # The homicide data is typically in the first large table
    # We'll process the largest table that likely contains the data
    df <- NULL
    for (i in seq_along(tables)) {
      tbl <- tables[[i]]
      # Look for tables with substantial data (>5 rows, multiple columns)
      if (nrow(tbl) > 5 && ncol(tbl) > 3) {
        cat(sprintf("[%s] Table %d: %d rows x %d columns\n", year, i, nrow(tbl), ncol(tbl)))
        
        # Check if this looks like homicide data (has relevant columns)
        col_names <- tolower(names(tbl))
        if (any(grepl("victim|name|age|date|method|address", col_names))) {
          df <- tbl
          break
        }
      }
    }
    
    if (is.null(df)) {
      # If no table found by column names, use the largest table
      sizes <- sapply(tables, function(x) nrow(x) * ncol(x))
      largest_idx <- which.max(sizes)
      df <- tables[[largest_idx]]
    }
    
    # Add year column
    df$Year <- year
    
    cat(sprintf("[%s] Successfully extracted data with %d rows\n", year, nrow(df)))
    return(df)
    
  }, error = function(e) {
    cat(sprintf("[ERROR] Failed to scrape %s: %s\n", year, e$message))
    return(NULL)
  })
}

# ============================================================================
# DATA CLEANING FUNCTIONS
# ============================================================================

#' Standardize column names
standardize_columns <- function(df) {
  # Get column names lowercased and cleaned
  col_names <- tolower(names(df))
  
  # Clean up common variations
  col_names <- gsub("^\\s+|\\s+$", "", col_names)  # Trim whitespace
  col_names <- gsub("\\s+", "_", col_names)        # Replace spaces with underscores
  
  names(df) <- col_names
  return(df)
}

#' Process and clean table headers
process_table_headers <- function(df) {
  # Save the year column if it exists
  year_col <- df$Year
  
  # Check if first row looks like headers (contains "Date", "Age", "Name", etc.)
  first_row <- df[1, ]
  header_keywords <- c("date", "age", "name", "address", "method", "camera", "closed", "notes")
  
  potential_headers <- sum(tolower(as.character(unlist(first_row))) %in% tolower(header_keywords)) +
                       sum(grepl("date|age|name|address|notes|camera|closed", 
                                tolower(as.character(unlist(first_row))), perl = TRUE))
  
  if (potential_headers > 3) {
    # Use first row as headers
    header_row <- as.character(df[1, ])
    # Clean up header names
    header_row <- tolower(header_row)
    header_row <- gsub("^\\s+|\\s+$", "", header_row)
    header_row <- gsub("\\s+", "_", header_row)
    header_row <- gsub("\\*.*$", "", header_row)  # Remove asterisks and notes
    # Replace NA and empty strings with generic names
    header_row <- ifelse(is.na(header_row) | header_row == "", 
                        paste0("col_", seq_along(header_row)), 
                        header_row)
    
    # Set column names
    names(df) <- header_row
    
    # Remove header row from data
    df <- df[-1, ]
    
    # Restore year column
    if (!is.null(year_col)) {
      df$year <- year_col[-1]  # Remove the header row entry
    }
    
    cat(sprintf("[DEBUG] Detected headers in first row. New column names: %s\n", 
                paste(names(df), collapse = ", ")))
  }
  
  return(df)
}

#' Find a column by pattern matching (flexible)
find_column <- function(df, patterns) {
  col_names <- tolower(names(df))
  
  for (pattern in patterns) {
    matches <- grep(pattern, col_names, ignore.case = TRUE)
    if (length(matches) > 0) {
      return(matches[1])
    }
  }
  return(NA)
}

#' Extract and clean victim age
extract_age <- function(age_str) {
  if (is.na(age_str) || age_str == "" || age_str == " ") {
    return(NA)
  }
  
  # Convert to character
  age_str <- as.character(age_str)
  
  # Remove common suffixes
  age_str <- str_trim(age_str)
  age_str <- str_remove(age_str, "\\s+years?\\s*old.*$")
  age_str <- str_remove(age_str, "\\s+yrs?\\s*old.*$")
  age_str <- str_remove(age_str, "\\s*\\(.*\\)$")
  
  # Extract first number
  age_match <- str_extract(age_str, "\\d+")
  
  if (is.na(age_match)) {
    return(NA)
  }
  
  age <- as.numeric(age_match)
  
  # Filter outliers and invalid ages
  if (age < 1 || age > 120) {
    return(NA)
  }
  
  return(age)
}

#' Extract date from various formats
extract_date <- function(date_str, year) {
  if (is.na(date_str) || date_str == "" || trimws(as.character(date_str)) == "") {
    return(as.POSIXct(NA))
  }
  
  date_str <- trimws(as.character(date_str))
  
  tryCatch({
    # Try parsing as month day format
    # Manually handle date formats since parse_date_time returns numeric
    date_parts <- strsplit(date_str, "[/-]")[[1]]
    
    if (length(date_parts) >= 2) {
      month_val <- as.integer(trimws(date_parts[1]))
      day_val <- as.integer(trimws(date_parts[2]))
      
      # Try to extract year if present
      year_val <- as.numeric(year)
      if (length(date_parts) >= 3) {
        year_extracted <- as.integer(trimws(date_parts[3]))
        # Handle 2-digit years
        if (year_extracted < 100) {
          year_val <- ifelse(year_extracted < 50, year_extracted + 2000, year_extracted + 1900)
        } else {
          year_val <- year_extracted
        }
      }
      
      # Validate month and day
      if (!is.na(month_val) && !is.na(day_val) && 
          month_val >= 1 && month_val <= 12 && 
          day_val >= 1 && day_val <= 31) {
        # Create POSIXct date
        date_str_formatted <- sprintf("%04d-%02d-%02d", year_val, month_val, day_val)
        result_date <- as.POSIXct(date_str_formatted, format = "%Y-%m-%d", tz = "UTC")
        if (!is.na(result_date)) {
          return(result_date)
        }
      }
    }
    
    return(as.POSIXct(NA))
  }, error = function(e) {
    return(as.POSIXct(NA))
  })
}

#' Clean and standardize homicide data
clean_homicide_data <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return(NULL)
  }
  
  # Standardize column names
  df <- standardize_columns(df)
  
  # Get the year
  year <- df$year[1]
  
  # Find relevant columns by pattern matching
  age_col <- find_column(df, c("age", "victim.*age", "age.*year"))
  date_col <- find_column(df, c("date", "date.*death", "death.*date", "incident.*date", "date.*incident"))
  method_col <- find_column(df, c("method", "cause", "how", "manner"))
  
  # Create a cleaned dataset
  cleaned <- df %>%
    mutate(
      # Clean age if column exists
      age = if (!is.na(age_col)) {
        sapply(df[[age_col]], extract_age)
      } else {
        NA_real_
      },
      
      # Extract date if column exists - force to POSIXct class
      date = if (!is.na(date_col)) {
        as.POSIXct(sapply(df[[date_col]], function(x) extract_date(x, year)))
      } else {
        as.POSIXct(NA)
      },
      
      # Clean method field if it exists
      method = if (!is.na(method_col)) {
        tolower(str_trim(df[[method_col]]))
      } else {
        NA_character_
      }
    ) %>%
    filter(!is.na(date) | !is.na(age)) %>%  # Keep rows with at least some data
    mutate(
      # Extract month, month_name, and day_of_week safely
      month = sapply(date, function(d) {
        if (is.na(d)) return(NA_integer_) 
        tryCatch(as.integer(month(d, label = FALSE)), error = function(e) NA_integer_)
      }),
      month_name = sapply(date, function(d) {
        if (is.na(d)) return(NA_character_) 
        tryCatch(as.character(month(d, label = TRUE)), error = function(e) NA_character_)
      }),
      day_of_week = sapply(date, function(d) {
        if (is.na(d)) return(NA_character_) 
        tryCatch(as.character(wday(d, label = TRUE)), error = function(e) NA_character_)
      })
    ) %>%
    select(year, age, date, month, month_name, day_of_week, method, everything())
  
  return(cleaned)
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

cat("\n========================================\n")
cat("Baltimore City Homicide Data Analysis\n")
cat("========================================\n\n")

# Scrape data from multiple years
all_data <- list()
for (year in names(URLS)) {
  data <- scrape_homicide_data(URLS[[year]], year)
  if (!is.null(data)) {
    all_data[[year]] <- data
  }
}

if (length(all_data) == 0) {
  cat("\n[ERROR] No data was successfully scraped from any URL.\n")
  quit(status = 1)
}

# Combine all data
combined_data <- bind_rows(all_data)
cat(sprintf("\nTotal records scraped: %d\n", nrow(combined_data)))

# Process table headers (detect if first row contains column names)
combined_data <- process_table_headers(combined_data)

# Clean the data
homicide_data <- clean_homicide_data(combined_data)

if (is.null(homicide_data) || nrow(homicide_data) == 0) {
  cat("\n[DEBUG] Combined data structure:\n")
  print(str(combined_data))
  cat("\n[DEBUG] Combined data first few rows:\n")
  print(head(combined_data))
  cat("\n[ERROR] No valid data after cleaning.\n")
  quit(status = 1)
}

# ============================================================================
# ANALYSIS: HOMICIDES BY MONTH
# ============================================================================

cat("\n========================================\n")
cat("ANALYSIS: Homicides by Month of Year\n")
cat("========================================\n\n")

cat("This analysis examines seasonal patterns in Baltimore homicides.\n")
cat("Understanding monthly variations can inform resource allocation\n")
cat("for police and prevention efforts.\n\n")

# Calculate monthly statistics
monthly_stats <- homicide_data %>%
  filter(!is.na(date)) %>%
  group_by(month, month_name) %>%
  summarise(
    count = n(),
    .groups = 'drop'
  ) %>%
  arrange(month)

# Fill in missing months with 0
all_months <- data.frame(month = 1:12)
all_months$month_name <- month(all_months$month, label = TRUE)
monthly_stats <- all_months %>%
  left_join(monthly_stats, by = c("month", "month_name")) %>%
  mutate(count = coalesce(count, 0L))

# Print tabular histogram
cat("TABULAR HISTOGRAM - HOMICIDES BY MONTH:\n")
cat("=====================================\n\n")
cat(sprintf("%-12s %6s %s\n", 
            "Month",
            "Count",
            "Histogram"))
cat(sprintf("%s\n", paste(rep("-", 50), collapse = "")))

for (i in seq_len(nrow(monthly_stats))) {
  month_label <- format(monthly_stats$month_name[i], width = 12)
  count <- monthly_stats$count[i]
  bars <- paste(rep("█", count), collapse = "")
  cat(sprintf("%s %6d %s\n", month_label, count, bars))
}

cat(sprintf("\n%s\n", paste(rep("-", 50), collapse = "")))
cat(sprintf("\nTotal Homicides: %d\n", sum(monthly_stats$count)))
cat(sprintf("Average per month: %.1f\n", mean(monthly_stats$count)))
cat(sprintf("Highest: %s (%d homicides)\n", 
            as.character(monthly_stats$month_name[which.max(monthly_stats$count)]),
            max(monthly_stats$count)))
cat(sprintf("Lowest: %s (%d homicides)\n", 
            as.character(monthly_stats$month_name[which.min(monthly_stats$count)]),
            min(monthly_stats$count)))

# ============================================================================
# ADDITIONAL ANALYSIS: AGE DISTRIBUTION
# ============================================================================

cat("\n========================================\n")
cat("ADDITIONAL ANALYSIS: Victim Age Distribution\n")
cat("========================================\n\n")

# Calculate age statistics
age_data <- homicide_data %>%
  filter(!is.na(age)) %>%
  mutate(
    age_group = cut(age, 
                    breaks = c(0, 18, 25, 35, 50, 65, 120),
                    labels = c("0-17", "18-24", "25-34", "35-49", "50-64", "65+"),
                    right = FALSE)
  )

age_stats <- age_data %>%
  group_by(age_group) %>%
  summarise(
    count = n(),
    .groups = 'drop'
  )

cat("TABULAR HISTOGRAM - VICTIM AGE DISTRIBUTION:\n")
cat("============================================\n\n")
cat(sprintf("%-15s %6s %s\n", 
            "Age Group",
            "Count",
            "Histogram"))
cat(sprintf("%s\n", paste(rep("-", 50), collapse = "")))

for (i in seq_len(nrow(age_stats))) {
  age_label <- format(age_stats$age_group[i], width = 15)
  count <- age_stats$count[i]
  bars <- paste(rep("█", count), collapse = "")
  cat(sprintf("%s %6d %s\n", age_label, count, bars))
}

cat(sprintf("\n%s\n", paste(rep("-", 50), collapse = "")))
cat(sprintf("Total victims with known age: %d\n", sum(age_stats$count)))

age_summary <- age_data %>%
  summarise(
    mean_age = mean(age, na.rm = TRUE),
    median_age = median(age, na.rm = TRUE),
    min_age = min(age, na.rm = TRUE),
    max_age = max(age, na.rm = TRUE),
    sd = sd(age, na.rm = TRUE)
  )

cat(sprintf("Mean age: %.1f years\n", age_summary$mean_age))
cat(sprintf("Median age: %.0f years\n", age_summary$median_age))
cat(sprintf("Age range: %d - %d years\n", age_summary$min_age, age_summary$max_age))

# ============================================================================
# METHOD ANALYSIS (if available)
# ============================================================================

if ("method" %in% names(homicide_data) && 
    sum(!is.na(homicide_data$method)) > 0) {
  
  cat("\n========================================\n")
  cat("METHOD ANALYSIS: Types of Homicides\n")
  cat("========================================\n\n")
  
  method_stats <- homicide_data %>%
    filter(!is.na(method)) %>%
    group_by(method) %>%
    summarise(
      count = n(),
      .groups = 'drop'
    ) %>%
    arrange(desc(count))
  
  cat("TABULAR HISTOGRAM - HOMICIDE METHODS:\n")
  cat("====================================\n\n")
  cat(sprintf("%-30s %6s %s\n", 
              "Method",
              "Count",
              "Histogram"))
  cat(sprintf("%s\n", paste(rep("-", 60), collapse = "")))
  
  for (i in seq_len(nrow(method_stats))) {
    method_label <- format(method_stats$method[i], width = 30, justify = "left")
    count <- method_stats$count[i]
    bars <- paste(rep("█", max(1, count %/% 2)), collapse = "")
    cat(sprintf("%s %6d %s\n", method_label, count, bars))
  }
  
  cat(sprintf("\n%s\n", paste(rep("-", 60), collapse = "")))
  cat(sprintf("Total with known method: %d\n", sum(method_stats$count)))
}

# ============================================================================
# SUMMARY STATISTICS
# ============================================================================

cat("\n========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n\n")

cat(sprintf("Years covered: %s\n", paste(sort(unique(homicide_data$year)), collapse = ", ")))
cat(sprintf("Total homicides: %d\n", nrow(homicide_data)))
cat(sprintf("Records with valid dates: %d\n", sum(!is.na(homicide_data$date))))
cat(sprintf("Records with known victim ages: %d\n", sum(!is.na(homicide_data$age))))

cat("\n========================================\n")
cat("END OF ANALYSIS\n")
cat("========================================\n\n")
