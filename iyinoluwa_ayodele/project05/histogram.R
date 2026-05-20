#!/usr/bin/env Rscript

# histogram.R - scrape Baltimore homicide data and produce histogram
# Usage: Rscript histogram.R

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
})

# function to fetch and parse table for a given year
fetch_year <- function(year) {
  url <- sprintf("https://chamspage.blogspot.com/%d/01/%d-baltimore-city-homicide-list.html", year, year)
  message("Fetching ", url)
  page <- tryCatch(read_html(url), error = function(e) {
    message("  failed to read: ", e$message)
    return(NULL)
  })
  if (is.null(page)) return(NULL)

  tbl <- page %>% html_node("table#homicidelist")
  if (is.null(tbl)) {
    message("  no table found on ", url)
    return(NULL)
  }
  # html_table tries to guess header; nested tables may cause issues but simple
  # extraction of text fields should work
  df <- tbl %>% html_table(fill = TRUE)

  # ensure expected columns exist
  # typical columns: No., Date Died, Name, Age, Address Block Found, Notes, ...
  if (ncol(df) < 4) {
    message("  unexpected table structure for year ", year)
    return(NULL)
  }

  # rename columns for convenience
  names(df)[1:6] <- c("No", "Date", "Name", "Age", "Location", "Notes")
  # There may be extra columns; keep them
  df$Year <- year
  return(df)
}

# gather data for multiple years
years <- c(2025, 2024, 2023)
raw_data <- lapply(years, fetch_year)
raw_data <- bind_rows(raw_data)

# clean
if (nrow(raw_data) == 0) {
  stop("No data collected")
}

# parse dates and ages
clean <- raw_data %>%
  mutate(
    Date = mdy(Date),
    Age = as.numeric(str_extract(Age, "[0-9]+"))
  )

# choose statistic: distribution of victim ages across years
hist_data <- clean %>%
  filter(!is.na(Age) & Age > 0) %>%
  select(Year, Age)

# print tabular histogram counts by age bin
bins <- seq(0, 100, by=10)
cut_ages <- cut(hist_data$Age, breaks=bins, include.lowest=TRUE, right=FALSE)
tab <- table(cut_ages)
cat("Age Distribution Histogram:\n")
print(tab)

# also show counts per year-age bin table
cat("\nDetailed counts by year:\n")
print(table(hist_data$Year, cut_ages))

# generate histogram plot file for manual inspection (not strictly needed)
png("histogram.png", width=800, height=600)
hist(hist_data$Age, breaks=bins, main="Distribution of Baltimore Homicide Victim Ages",
     xlab="Age", ylab="Count", col="steelblue", border="black")
dev.off()

cat("\nHistogram saved to histogram.png\n")

message("Done")
