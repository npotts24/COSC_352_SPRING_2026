#!/usr/bin/env Rscript
# Baltimore City Homicide Data Analysis and Visualization
# Scrapes data from https://chamspage.blogspot.com/
# Analyzes and visualizes homicide statistics

# Install and load required packages
required_packages <- c("rvest", "dplyr", "stringr", "ggplot2", "lubridate", "tidyr")

for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "http://cran.r-project.org")
    library(pkg, character.only = TRUE)
  }
}

# URLs for homicide data (2023-2025)
urls <- list(
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  "2023" = "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html"
)

# Function to scrape and parse homicide data from a URL
scrape_homicide_data <- function(url, year) {
  cat(sprintf("Scraping %s data from: %s\n", year, url))
  
  tryCatch({
    # Fetch the HTML page
    page <- read_html(url)
    
    # Extract the main table
    tables <- page %>% html_table(fill = TRUE)
    
    if (length(tables) == 0) {
      cat(sprintf("Warning: No tables found on page for %s\n", year))
      return(NULL)
    }
    
    # Usually the first or second table contains the data
    # Try different table indices
    data <- NULL
    for (i in seq_along(tables)) {
      table_df <- tables[[i]]
      if (nrow(table_df) > 5 && ncol(table_df) >= 3) {
        data <- table_df
        break
      }
    }
    
    if (is.null(data)) {
      cat(sprintf("Warning: Could not find a suitable table for %s\n", year))
      return(NULL)
    }
    
    # Clean up column names
    names(data) <- tolower(trimws(names(data)))
    
    # Add year column
    data$year <- year
    
    return(as.data.frame(data))
    
  }, error = function(e) {
    cat(sprintf("Error scraping %s: %s\n", year, e$message))
    return(NULL)
  })
}

# Scrape all years
all_data <- list()
for (year in names(urls)) {
  data <- scrape_homicide_data(urls[[year]], year)
  if (!is.null(data)) {
    all_data[[year]] <- data
  }
}

# Combine all data
if (length(all_data) == 0) {
  stop("Failed to scrape any data from the blog.")
}

df <- bind_rows(all_data)
df$year <- as.character(df$year)

# Data cleaning and preprocessing
clean_homicide_data <- function(df) {
  # Display original column names for debugging
  cat("\nOriginal column names:\n")
  print(colnames(df))
  cat("\nFirst few rows of raw data:\n")
  print(head(df, 2))
  
  # Normalize column names
  names(df) <- tolower(trimws(names(df)))
  
  # Select relevant columns (age is key for our analysis)
  # Look for columns containing "age", "name", "date", "method", etc.
  age_col <- names(df)[grepl("age", names(df), ignore.case = TRUE)][1]
  date_col <- names(df)[grepl("date|incident", names(df), ignore.case = TRUE)][1]
  method_col <- names(df)[grepl("method", names(df), ignore.case = TRUE)][1]
  
  # Extract numeric ages
  if (!is.na(age_col)) {
    df$age_numeric <- as.numeric(gsub("[^0-9]", "", df[[age_col]]))
    df$age_numeric <- ifelse(is.na(df$age_numeric), df$age_numeric, df$age_numeric)
  }
  
  return(df)
}

df <- clean_homicide_data(df)

# Analyze available numeric columns for histogram
cat("\n\nAnalyzing data structure:\n")
cat("Total records: ", nrow(df), "\n")
cat("Total columns: ", ncol(df), "\n")
cat("Column names:\n")
print(colnames(df))

# Look for numeric columns to analyze
numeric_cols <- names(df)[sapply(df, is.numeric)]
cat("\nNumeric columns found:\n")
print(numeric_cols)

# If age_numeric exists and has values, use it for the main analysis
if ("age_numeric" %in% names(df)) {
  df_clean <- df %>%
    filter(!is.na(age_numeric)) %>%
    filter(age_numeric > 0, age_numeric < 120)  # Remove nonsensical ages
  
  if (nrow(df_clean) > 0) {
    cat("\n=== BALTIMORE CITY HOMICIDE DATA ANALYSIS ===\n")
    cat("Analysis: Distribution of Victim Ages\n")
    cat("Years included: ", paste(unique(df_clean$year), collapse = ", "), "\n")
    cat("Total homicides with valid age data: ", nrow(df_clean), "\n\n")
    
    # Create age groups for histogram
    df_clean$age_group <- cut(df_clean$age_numeric, 
                              breaks = seq(0, 120, by = 10),
                              right = FALSE,
                              labels = paste0(seq(0, 110, by = 10), "-", 
                                            seq(10, 120, by = 10)))
    
    # Create tabular histogram
    age_histogram <- df_clean %>%
      group_by(age_group) %>%
      summarise(count = n(), .groups = 'drop') %>%
      mutate(percentage = round(100 * count / sum(count), 1))
    
    cat("VICTIM AGE DISTRIBUTION (HISTOGRAM DATA):\n")
    cat("============================================\n")
    print(as.data.frame(age_histogram))
    
    # Basic statistics
    cat("\n\nAGE STATISTICS:\n")
    cat("Mean age: ", round(mean(df_clean$age_numeric, na.rm = TRUE), 1), "\n")
    cat("Median age: ", round(median(df_clean$age_numeric, na.rm = TRUE), 1), "\n")
    cat("Std Dev: ", round(sd(df_clean$age_numeric, na.rm = TRUE), 1), "\n")
    cat("Min age: ", min(df_clean$age_numeric, na.rm = TRUE), "\n")
    cat("Max age: ", max(df_clean$age_numeric, na.rm = TRUE), "\n")
    
    # Create and save ggplot histogram
    p <- ggplot(df_clean, aes(x = age_numeric)) +
      geom_histogram(binwidth = 5, fill = "#d62728", color = "black", alpha = 0.7) +
      labs(
        title = "Baltimore City Homicide Victims: Age Distribution",
        subtitle = paste("Data from", paste(unique(df_clean$year), collapse = ", ")),
        x = "Victim Age (years)",
        y = "Number of Homicides",
        caption = "Source: https://chamspage.blogspot.com/"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 14, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 11, hjust = 0.5),
        axis.title = element_text(size = 10, face = "bold"),
        axis.text = element_text(size = 9),
        panel.grid.major = element_line(color = "gray90"),
        panel.grid.minor = element_blank()
      )
    
    # Save the plot
    ggsave("histogram.png", p, width = 10, height = 6, dpi = 100)
    cat("\n\nHistogram saved to: histogram.png\n")
    
  } else {
    cat("Warning: No valid age data found after cleaning.\n")
  }
} else {
  cat("Note: Age column not found in the data.\n")
}

# Alternative analysis: Homicides by year and month (if date column exists)
date_cols <- names(df)[grepl("date|incident", names(df), ignore.case = TRUE)]
if (length(date_cols) > 0) {
  cat("\n\n=== YEAR-OVER-YEAR COMPARISON ===\n")
  
  year_summary <- df %>%
    group_by(year) %>%
    summarise(homicides = n(), .groups = 'drop') %>%
    arrange(as.numeric(year))
  
  cat("Homicides by Year:\n")
  print(as.data.frame(year_summary))
}

cat("\n=== Analysis Complete ===\n")
