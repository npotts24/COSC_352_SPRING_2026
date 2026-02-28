#!/usr/bin/env Rscript
# Baltimore City Homicide Data Analysis
# Scrapes, parses, and visualizes homicide data from chamspage.blogspot.com

# Install/load required packages
packages <- c("rvest", "dplyr", "stringr", "ggplot2", "lubridate", "tidyr")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org/")
    library(pkg, character.only = TRUE)
  }
}

# ============================================================================
# STEP 1: SCRAPE DATA FROM BLOG
# ============================================================================
# Fetch the 2025 Baltimore homicide list and additional years for richer analysis
urls <- list(
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  "2023" = "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html"
)

all_homicides <- data.frame()

# Scrape each year
for (year in names(urls)) {
  cat("Scraping", year, "homicide data...\n")
  
  tryCatch({
    page <- read_html(urls[[year]])
    
    # Extract all tables from the page
    tables <- html_table(page, fill = TRUE)

    # Candidate tables: prefer those with multiple rows
    candidate_tables <- Filter(function(t) nrow(t) > 3, tables)

    # If no candidate tables found, try taking any table with rows
    if (length(candidate_tables) == 0 && length(tables) > 0) {
      candidate_tables <- tables
    }

    # Add all candidate tables (with some normalization)
    for (tbl in candidate_tables) {
      tbl_df <- as.data.frame(tbl, stringsAsFactors = FALSE)
      tbl_df$year <- year
      colnames(tbl_df) <- tolower(colnames(tbl_df))
      all_homicides <- bind_rows(all_homicides, tbl_df)
    }
  }, error = function(e) {
    cat("error fetching", year, ":", conditionMessage(e), "\n")
  })
  
  # Be respectful to the server
  Sys.sleep(2)
}

if (nrow(all_homicides) == 0) {
  cat("Error: No homicide data was successfully scraped.\n")
  q(status = 1)
}

cat("Successfully scraped", nrow(all_homicides), "entries across multiple years.\n\n")

# ============================================================================
# STEP 2: DATA CLEANING AND PARSING
# ============================================================================
# Extract year/month from date column and numeric age values
# Handle various date formats and missing data

homicides <- all_homicides %>%
  # Trim whitespace
  mutate(across(everything(), ~str_trim(.))) %>%
  # Remove rows that are all empty
  filter(!if_all(everything(), ~. == "" | is.na(.)))

# Find and parse date column
date_cols <- grep("(?i)date|month", colnames(homicides), ignore.case = TRUE)
date_col <- NULL
if (length(date_cols) > 0) {
  date_col <- colnames(homicides)[date_cols[1]]
} else {
  # Try to detect a date-like column by content (mm/dd/yyyy or month names)
  date_like_regex <- "(\\b\\d{1,2}[/\\-]\\d{1,2}[/\\-]\\d{2,4}\\b|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"
  for (col in colnames(homicides)) {
    col_vals <- as.character(homicides[[col]])
    if (any(grepl(date_like_regex, tolower(col_vals), perl = TRUE), na.rm = TRUE)) {
      date_col <- col
      break
    }
  }
}

if (!is.null(date_col)) {
  # Parse dates - handle various formats
  homicides$parsed_date <- tryCatch({
    parse_date_time(homicides[[date_col]], 
                    orders = c("mdy", "dmy", "ymd", "m/d/y", "d/m/y", "b d, Y"),
                    locale = "en_US")
  }, error = function(e) {
    cat("Note: Could not fully parse all dates. Using partial matching.\n")
    NA
  })
  
  # Extract month from parsed date
  homicides$month <- month(homicides$parsed_date)
  homicides$day_of_week <- wday(homicides$parsed_date, label = TRUE)
  
  # If month parsing failed, try direct extraction from date string
  if (all(is.na(homicides$month))) {
    homicides$month <- str_extract(homicides[[date_col]], "\\\\d{1,2}") %>% as.numeric()
  }
}

# Attempt to detect an age column by content (numbers 0-120)
if (!"age" %in% colnames(homicides)) {
  for (col in colnames(homicides)) {
    # look for values with small integers
    vals <- homicides[[col]]
    nums <- suppressWarnings(as.numeric(str_extract(as.character(vals), "\\d+")))
    if (any(!is.na(nums) & nums >= 0 & nums <= 120, na.rm = TRUE)) {
      homicides$age <- nums
      break
    }
  }
} else {
  # existing age parsing if column named age exists
  homicides$age <- suppressWarnings(
    as.numeric(str_extract(as.character(homicides$age), "\\d+"))
  )
}


# Find and parse method column
method_cols <- grep("(?i)method", colnames(homicides), ignore.case = TRUE)

if (length(method_cols) > 0) {
  method_col <- colnames(homicides)[method_cols[1]]
  homicides$method <- tolower(homicides[[method_col]])
}

cat("Data cleaning complete.\n")
cat("Total records after cleaning:", nrow(homicides), "\n")
cat("Fields extracted: ", paste(names(homicides), collapse = ", "), "\n\n")

# ============================================================================
# STEP 3: ANALYZE AND CREATE STATISTIC
# ============================================================================
# We'll analyze homicides by MONTH - showing seasonality in Baltimore homicides
# This is interesting because it reveals temporal patterns in violent crime

cat("=== ANALYSIS: Homicides by Month (2023-2025) ===\n\n")

# Create analysis dataframe
month_names <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", 
                 "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

# Count homicides by month
monthly_counts <- homicides %>%
  filter(!is.na(month), month >= 1, month <= 12) %>%
  group_by(month) %>%
  summarise(
    count = n(),
    avg_age = mean(age, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(month) %>%
  mutate(
    month_name = month_names[month],
    percentage = round(count / sum(count) * 100, 1)
  )

# If insufficient monthly data, fall back to age distribution
if (nrow(monthly_counts) < 6) {
  cat("Note: Insufficient monthly data. Analyzing age distribution instead.\n\n")
  
  age_histogram_data <- homicides %>%
    filter(!is.na(age), age > 0, age < 120) %>%
    mutate(age_group = cut(age, 
                           breaks = seq(0, 120, by = 10),
                           include.lowest = TRUE)) %>%
    group_by(age_group) %>%
    summarise(count = n(), .groups = 'drop') %>%
    mutate(percentage = round(count / sum(count) * 100, 1))
  
  # Display tabular histogram for age groups
  cat("Age Distribution of Homicide Victims (2023-2025)\n")
  cat(strrep("=", 50), "\n")
  cat(sprintf("%-15s %6s %8s\n", "Age Group", "Count", "Percent"))
  cat(strrep("-", 50), "\n")
  
  for (i in 1:nrow(age_histogram_data)) {
    cat(sprintf("%-15s %6d %7.1f%%\n", 
                age_histogram_data$age_group[i],
                age_histogram_data$count[i],
                age_histogram_data$percentage[i]))
  }
  
  histogram_data <- age_histogram_data
  histogram_title <- "Age Distribution of Baltimore Homicide Victims"
  
} else {
  # Display tabular histogram for monthly data
  cat("Homicides by Month (2023-2025 Combined)\n")
  cat(strrep("=", 60), "\n")
  cat(sprintf("%-12s %6s %8s %12s\n", "Month", "Count", "Percent", "Avg Victim Age"))
  cat(strrep("-", 60), "\n")
  
  for (i in 1:nrow(monthly_counts)) {
    cat(sprintf("%-12s %6d %7.1f%% %12.1f\n", 
                monthly_counts$month_name[i],
                monthly_counts$count[i],
                monthly_counts$percentage[i],
                monthly_counts$avg_age[i]))
  }
  
  histogram_data <- monthly_counts
  histogram_title <- "Baltimore City Homicides by Month (2023-2025)"
}

cat(strrep("=", 60), "\n\n")

# ============================================================================
# STEP 4: CREATE AND DISPLAY HISTOGRAM
# ============================================================================

# Determine plot details based on data type
if (exists("age_histogram_data")) {
  p <- ggplot(age_histogram_data, aes(x = age_group, y = count)) +
    geom_bar(stat = "identity", fill = "#C41E3A", color = "black", alpha = 0.8) +
    geom_text(aes(label = count), vjust = -0.5, fontface = "bold") +
    labs(
      title = histogram_title,
      subtitle = "Data scraped from chamspage.blogspot.com (2023-2025 combined)",
      x = "Age Group (years)",
      y = "Number of Victims",
      caption = "Visualization of Baltimore homicide victim age distribution"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.text.x = element_text(angle = 45, hjust = 1),
      panel.grid.major.y = element_line(color = "gray90"),
      panel.grid.major.x = element_blank()
    )
} else {
  p <- ggplot(monthly_counts, aes(x = reorder(month_name, month), y = count)) +
    geom_bar(stat = "identity", fill = "#C41E3A", color = "black", alpha = 0.8) +
    geom_text(aes(label = count), vjust = -0.5, fontface = "bold") +
    labs(
      title = histogram_title,
      subtitle = "Data scraped from chamspage.blogspot.com (2023-2025 combined)",
      x = "Month",
      y = "Number of Homicides",
      caption = "Shows seasonal patterns in Baltimore homicide data"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      axis.text.x = element_text(angle = 45, hjust = 1),
      panel.grid.major.y = element_line(color = "gray90"),
      panel.grid.major.x = element_blank()
    )
}

# Save and display
ggsave("histogram.png", p, width = 10, height = 6, dpi = 300)
print(p)

cat("\n✓ Histogram saved as histogram.png\n")
cat("✓ Analysis complete!\n")
