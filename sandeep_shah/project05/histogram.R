# =====================================================
# Baltimore Homicides Histogram - FINAL CLEAN VERSION
# Prints output once and exits
# =====================================================

library(rvest)
library(dplyr)
library(lubridate)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Fetching data...\n")

# -------------------------------
# Scrape webpage
# -------------------------------

page <- read_html(url)
tables <- html_table(page, fill = TRUE)

if (length(tables) == 0) {
  stop("No tables found.")
}

# -------------------------------
# Select correct homicide table ONLY once
# -------------------------------

df <- NULL

for (tbl in tables) {

  # Fix header
  colnames(tbl) <- as.character(unlist(tbl[1, ]))
  tbl <- tbl[-1, ]

  # Normalize column names
  colnames(tbl) <- make.names(colnames(tbl), unique = TRUE)
  tbl <- tbl[, !is.na(colnames(tbl))]

  # If Date column exists, use this table
  if (any(grepl("Date", colnames(tbl), ignore.case = TRUE))) {
    df <- tbl
    break
  }
}

if (is.null(df)) {
  stop("Homicide table not found.")
}

# -------------------------------
# Clean Date Column
# -------------------------------

date_col <- grep("Date", colnames(df), ignore.case = TRUE, value = TRUE)

df$date_clean <- mdy(df[[date_col[1]]])
df <- df[!is.na(df$date_clean), ]

# -------------------------------
# Compute Weekday Histogram
# -------------------------------

df$weekday <- wday(df$date_clean,
                   label = TRUE,
                   abbr = FALSE)

weekday_counts <- df %>%
  count(weekday) %>%
  arrange(match(weekday,
                 c("Sunday","Monday","Tuesday",
                   "Wednesday","Thursday",
                   "Friday","Saturday")))

# -------------------------------
# Print Output ONCE
# -------------------------------

cat("\nHomicides by Day of Week (2025)\n")
cat("---------------------------------\n")
print(weekday_counts)

# -------------------------------
# Plot Histogram
# -------------------------------

plot <- ggplot(weekday_counts, aes(x = weekday, y = n)) +
  geom_col(fill = "#8B0000", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.5, size = 5) +
  labs(
    title = "Baltimore City Homicides by Day of Week (2025)",
    x = "Day of Week",
    y = "Number of Homicides"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.title = element_text(face = "bold")
  )

ggsave("histogram.png", plot, width = 10, height = 6)

cat("\nHistogram saved as histogram.png\n")

# -------------------------------
# STOP SCRIPT (VERY IMPORTANT)
# -------------------------------

quit(save = "no")# =====================================================
# Baltimore Homicides by Day of Week Histogram (2025)
# Clean Production Version - Single Execution Only
# =====================================================

library(rvest)
library(dplyr)
library(lubridate)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Fetching data...\n")

# -------------------------------
# Scrape webpage
# -------------------------------

page <- read_html(url)
tables <- html_table(page, fill = TRUE)

if (length(tables) == 0) {
  stop("No tables found on webpage.")
}

# -------------------------------
# Find correct homicide table
# -------------------------------

df <- NULL

for (tbl in tables) {

  # Fix headers (first row sometimes contains header text)
  colnames(tbl) <- as.character(unlist(tbl[1, ]))
  tbl <- tbl[-1, ]

  # Remove empty column names
  colnames(tbl) <- make.names(colnames(tbl), unique = TRUE)
  tbl <- tbl[, !is.na(colnames(tbl))]

  # Look for Date Died column
  if (any(grepl("Date", colnames(tbl), ignore.case = TRUE))) {
    df <- tbl
    break
  }
}

if (is.null(df)) {
  stop("Homicide data table not found.")
}

cat("Using table columns:\n")
print(colnames(df))

# -------------------------------
# Clean date column
# -------------------------------

date_col <- grep("Date", colnames(df), ignore.case = TRUE, value = TRUE)

df$date_clean <- mdy(df[[date_col[1]]])

df <- df[!is.na(df$date_clean), ]

# -------------------------------
# Compute weekday counts
# -------------------------------

df$weekday <- wday(df$date_clean,
                   label = TRUE,
                   abbr = FALSE)

weekday_counts <- df %>%
  count(weekday)

weekday_counts$weekday <- factor(
  weekday_counts$weekday,
  levels = c("Sunday","Monday","Tuesday","Wednesday",
             "Thursday","Friday","Saturday")
)

weekday_counts <- weekday_counts %>% arrange(weekday)

# -------------------------------
# Print histogram table to stdout
# -------------------------------

cat("\nHomicides by Day of Week (2025)\n")
cat("---------------------------------\n")
print(weekday_counts)

# -------------------------------
# Generate histogram plot
# -------------------------------

plot <- ggplot(weekday_counts, aes(x = weekday, y = n)) +
  geom_col(fill = "#8B0000", color = "black", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.5, size = 5) +
  labs(
    title = "Baltimore City Homicides by Day of Week (2025)",
    subtitle = "Data Source: Cham's Page Blog",
    x = "Day of Week",
    y = "Number of Homicides"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("histogram.png", plot = plot, width = 10, height = 6)

cat("\nHistogram saved as histogram.png\n")# ===============================
# Baltimore Homicides by Day of Week (2025)
# ===============================

library(rvest)
library(dplyr)
library(lubridate)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Fetching data...\n")

page <- read_html(url)
tables <- page %>% html_table(fill = TRUE)

if (length(tables) == 0) {
  stop("No tables found on page.")
}

# ---- FIND CORRECT TABLE ----
df <- NULL

for (tbl in tables) {

  # promote first row to header
  colnames(tbl) <- as.character(unlist(tbl[1, ]))
  tbl <- tbl[-1, ]

  # remove columns with NA names
  tbl <- tbl[, !is.na(colnames(tbl))]

  # check if this table has Date column
  if (any(grepl("Date Died", colnames(tbl), ignore.case = TRUE))) {
    df <- tbl
    break
  }
}

if (is.null(df)) {
  stop("Could not find homicide data table.")
}

cat("Using table with columns:\n")
print(colnames(df))

# ---- CLEAN DATE ----
df$date_clean <- mdy(df$`Date Died`)
df <- df[!is.na(df$date_clean), ]

# ---- ADD WEEKDAY ----
df$weekday <- wday(df$date_clean, label = TRUE, abbr = FALSE)

# ---- COUNT ----
weekday_counts <- df %>%
  count(weekday)

weekday_counts$weekday <- factor(
  weekday_counts$weekday,
  levels = c("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")
)

weekday_counts <- weekday_counts %>% arrange(weekday)

# ---- PRINT TABULAR HISTOGRAM ----
cat("\nHomicides by Day of Week (2025)\n")
cat("---------------------------------\n")
print(weekday_counts)

# ---- BEAUTIFUL HISTOGRAM ----
plot <- ggplot(weekday_counts, aes(x = weekday, y = n)) +
  geom_col(fill = "#8B0000", color = "black", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.5, size = 5) +
  labs(
    title = "Baltimore City Homicides by Day of Week (2025)",
    subtitle = "Data Source: Cham's Page Blog",
    x = "Day of Week",
    y = "Number of Homicides"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("histogram.png", plot = plot, width = 10, height = 6)

cat("\nHistogram saved as histogram.png\n")# ===============================
# Baltimore Homicides by Day of Week (2025)
# ===============================

library(rvest)
library(dplyr)
library(stringr)
library(lubridate)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Fetching data...\n")

page <- read_html(url)
tables <- page %>% html_table(fill = TRUE)

if (length(tables) == 0) {
  stop("No tables found on page.")
}

df <- tables[[1]]

# ---- FIX HEADER ----
colnames(df) <- as.character(unlist(df[1, ]))
df <- df[-1, ]

# ---- REMOVE COLUMNS WITH NA NAMES ----
df <- df[, !is.na(colnames(df))]

cat("Detected Columns After Cleaning:\n")
print(colnames(df))

# ---- FIND DATE COLUMN ----
date_col <- grep("date", colnames(df), ignore.case = TRUE, value = TRUE)

if (length(date_col) == 0) {
  stop("Could not find Date column.")
}

# ---- CLEAN DATE ----
df$date_clean <- mdy(df[[date_col[1]]])
df <- df[!is.na(df$date_clean), ]

# ---- ADD WEEKDAY ----
df$weekday <- wday(df$date_clean, label = TRUE, abbr = FALSE)

# ---- COUNT ----
weekday_counts <- df %>%
  count(weekday)

weekday_counts$weekday <- factor(
  weekday_counts$weekday,
  levels = c("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")
)

weekday_counts <- weekday_counts %>% arrange(weekday)

# ---- PRINT TABULAR HISTOGRAM ----
cat("\nHomicides by Day of Week (2025)\n")
cat("---------------------------------\n")
print(weekday_counts)

# ---- BEAUTIFUL HISTOGRAM ----
plot <- ggplot(weekday_counts, aes(x = weekday, y = n)) +
  geom_col(fill = "#8B0000", color = "black", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.5, size = 5) +
  labs(
    title = "Baltimore City Homicides by Day of Week (2025)",
    subtitle = "Data Source: Cham's Page Blog",
    x = "Day of Week",
    y = "Number of Homicides"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("histogram.png", plot = plot, width = 10, height = 6)

cat("\nHistogram saved as histogram.png\n")# ===============================
# Baltimore Homicides by Day of Week (2025)
# ===============================

library(rvest)
library(dplyr)
library(stringr)
library(lubridate)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Fetching data...\n")

page <- read_html(url)
tables <- page %>% html_table(fill = TRUE)

if (length(tables) == 0) {
  stop("No tables found on page.")
}

df <- tables[[1]]

# ---- FIX MESSY HEADER ----
# First row contains real column names
colnames(df) <- as.character(unlist(df[1, ]))
df <- df[-1, ]

cat("Detected Columns After Cleaning:\n")
print(colnames(df))

# Find Date column (case insensitive)
date_col <- grep("date", colnames(df), ignore.case = TRUE, value = TRUE)

if (length(date_col) == 0) {
  stop("Could not find Date column.")
}

# Convert to Date
df$date_clean <- mdy(df[[date_col[1]]])

# Remove invalid rows
df <- df %>% filter(!is.na(date_clean))

# Extract weekday
df$weekday <- wday(df$date_clean, label = TRUE, abbr = FALSE)

# Count per weekday
weekday_counts <- df %>%
  count(weekday)

# Order correctly
weekday_counts$weekday <- factor(
  weekday_counts$weekday,
  levels = c("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")
)

weekday_counts <- weekday_counts %>% arrange(weekday)

# ---- PRINT TABULAR HISTOGRAM ----
cat("\nHomicides by Day of Week (2025)\n")
cat("---------------------------------\n")
print(weekday_counts)

# ---- BEAUTIFUL HISTOGRAM ----
plot <- ggplot(weekday_counts, aes(x = weekday, y = n)) +
  geom_col(fill = "#8B0000", color = "black", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.5, size = 5) +
  labs(
    title = "Baltimore City Homicides by Day of Week (2025)",
    subtitle = "Data Source: Cham's Page Blog",
    x = "Day of Week",
    y = "Number of Homicides"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("histogram.png", plot = plot, width = 10, height = 6)

cat("\nHistogram saved as histogram.png\n")# ===============================
# Baltimore Homicides by Day of Week (2025)
# ===============================

library(rvest)
library(dplyr)
library(stringr)
library(lubridate)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Fetching data...\n")

page <- read_html(url)

tables <- page %>% html_table(fill = TRUE)

if (length(tables) == 0) {
  stop("No tables found on page.")
}

df <- tables[[1]]

# Print column names so we know structure
cat("Columns detected:\n")
print(colnames(df))

# ---- IMPORTANT ----
# From inspecting this blog, the Date column is usually named "Date"
# If it fails later, we adjust.

if (!"Date" %in% colnames(df)) {
  stop("Date column not found. Check table structure.")
}

# Clean and convert dates
df$date_clean <- mdy(df$Date)

df <- df %>% filter(!is.na(date_clean))

# Extract weekday
df$weekday <- wday(df$date_clean, label = TRUE, abbr = FALSE)

# Count homicides per weekday
weekday_counts <- df %>%
  count(weekday)

# Order correctly
weekday_counts$weekday <- factor(
  weekday_counts$weekday,
  levels = c("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")
)

weekday_counts <- weekday_counts %>%
  arrange(weekday)

# ---- PRINT TABULAR HISTOGRAM ----
cat("\nHomicides by Day of Week (2025)\n")
cat("---------------------------------\n")
print(weekday_counts)

# ---- BEAUTIFUL HISTOGRAM ----
plot <- ggplot(weekday_counts, aes(x = weekday, y = n)) +
  geom_col(fill = "#8B0000", color = "black", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.5, size = 5) +
  labs(
    title = "Baltimore City Homicides by Day of Week (2025)",
    subtitle = "Data Source: Cham's Page Blog",
    x = "Day of Week",
    y = "Number of Homicides"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("histogram.png", plot = plot, width = 10, height = 6)

cat("\nHistogram saved as histogram.png\n")# ===============================

# Install/load libraries
library(rvest)
library(dplyr)
library(stringr)
library(lubridate)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Fetching data...\n")

# Read webpage
page <- read_html(url)

# Extract tables
tables <- page %>% html_table(fill = TRUE)

if (length(tables) == 0) {
  stop("No tables found on page.")
}

# Use first table
df <- tables[[1]]

# Clean column names
colnames(df) <- make.names(colnames(df))

# Try to find date column
date_column <- df %>%
  select(where(~ any(str_detect(., "\\d{1,2}/\\d{1,2}/\\d{4}")))) %>%
  names()

if (length(date_column) == 0) {
  stop("Could not detect date column.")
}

# Extract date column
df$date <- mdy(df[[date_column[1]]])

# Remove rows with bad dates
df <- df %>% filter(!is.na(date))

# Add weekday
df$weekday <- wday(df$date, label = TRUE, abbr = FALSE)

# Count homicides per weekday
weekday_counts <- df %>%
  count(weekday) %>%
  arrange(match(weekday,
                c("Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday")))

# Print tabular histogram to stdout
cat("\nHomicides by Day of Week (2025)\n")
cat("---------------------------------\n")
print(weekday_counts)

# Create beautiful histogram
plot <- ggplot(weekday_counts, aes(x = weekday, y = n)) +
  geom_col(fill = "#8B0000", color = "black", width = 0.7) +
  geom_text(aes(label = n), vjust = -0.5, size = 5) +
  labs(
    title = "Baltimore City Homicides by Day of Week (2025)",
    subtitle = "Data Source: Cham's Page Blog",
    x = "Day of Week",
    y = "Number of Homicides"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("histogram.png", plot = plot, width = 10, height = 6)

cat("\nHistogram saved as histogram.png\n")


quit(save = "no")
