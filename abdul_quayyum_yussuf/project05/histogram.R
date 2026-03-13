#!/usr/bin/env Rscript

# histogram.R
# Scrape, clean, and visualize Baltimore homicide data from chamspage for 2025 and 2026.
# We focus on the distribution of victim ages and print a tabular histogram to stdout.

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(ggplot2)
  library(lubridate)
})

# URLs for both 2025 and 2026 lists
urls <- list(
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "2026" = "https://chamspage.blogspot.com/2026/01/2026-baltimore-city-homicide-list.html"
)

# function to extract and clean homicide data from a given URL
extract_homicide_data <- function(url) {
  page <- read_html(url)
  tbl <- html_node(page, "#homicidelist")
  raw <- html_table(tbl, fill = TRUE)
  
  if (nrow(raw) == 0) return(NULL)
  
  colnames(raw) <- as.character(raw[1, ])
  data <- raw[-1, ]
  data <- data %>% select(1:9)
  colnames(data) <- c(
    "No", "Date", "Name", "Age", "Address", "Notes",
    "NoCriminalHistory", "Camera", "CaseClosed"
  )
  data <- data %>% filter(str_trim(Date) != "" & !is.na(Date))
  data
}

# scrape both years and combine
cat("Scraping 2025 and 2026 Baltimore City Homicide Lists...\n")
all_data <- NULL
for (year in names(urls)) {
  data <- extract_homicide_data(urls[[year]])
  if (!is.null(data)) {
    data$Year <- year
    all_data <- bind_rows(all_data, data)
  }
}

if (is.null(all_data) || nrow(all_data) == 0) {
  stop("No homicide data found")
}

cat(sprintf("\nCombined Data: %d records from 2025 and 2026\n\n", nrow(all_data)))

# convert age to numeric; non-numeric entries become NA
all_data <- all_data %>% mutate(AgeNum = as.numeric(str_extract(Age, "\\d+")))

# keep only rows where we actually have a numeric age
ages <- all_data %>% filter(!is.na(AgeNum)) %>% pull(AgeNum)

if (length(ages) == 0) {
  stop("no valid ages found")
}

# compute histogram bins (5-year intervals up to 100)
breaks <- seq(0, 100, by = 5)
h <- hist(ages, breaks = breaks, plot = FALSE)

# create a printable table of ranges and counts
hist_table <- data.frame(
  range = paste(head(h$breaks, -1), h$breaks[-1], sep = "-"),
  count = h$counts
)

# print tabular histogram to stdout
cat("========================================\n")
cat("Analysis based on 2025 and 2026 Baltimore City Homicide Lists\n")
cat("========================================\n\n")
cat("Tabular histogram (age bins)\n")
print(hist_table, row.names = FALSE)
cat("\n")

# draw and save the plot as a png file in the current working directory
out_file <- file.path(getwd(), "histogram.png")
# ensure output directory exists (should be the mounted host folder when run via run.sh)
if (!dir.exists(dirname(out_file))) dir.create(dirname(out_file), recursive = TRUE)
png(out_file, width = 800, height = 600)
hist(
  ages,
  breaks = breaks,
  main = "Distribution of Victim Ages in 2025-2026 Baltimore Homicides",
  xlab = "Age",
  ylab = "Count",
  col = "steelblue",
  border = "black"
)
dev.off()

cat(sprintf("Saved histogram plot to %s\n", out_file))
