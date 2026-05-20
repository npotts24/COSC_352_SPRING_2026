# -----------------------------------
# 2025 Baltimore Homicide Age Analysis
# -----------------------------------

library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)

# URL
url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

# Read webpage
page <- read_html(url)

# Extract tables
tables <- html_table(page, fill = TRUE)

# First table contains the data
data <- tables[[1]]

# Remove first row (header row inside table body)
data <- data[-1, ]


# CLEANING

# Extract column 4 directly (Age column)
age_values <- data[[4]]

# Remove blanks
age_values <- age_values[age_values != ""]

# Remove entries with "mo"
age_values <- age_values[!str_detect(age_values, "mo")]

# Convert to numeric
age_values <- as.numeric(age_values)

# Remove NA
age_values <- age_values[!is.na(age_values)]

# Clean dataframe for plotting
clean_data <- data.frame(Age = age_values)


# HISTOGRAM

histogram_plot <- ggplot(clean_data, aes(x = Age)) +
  geom_histogram(binwidth = 5, fill = "skyblue", color = "black") +
  labs(
    title = "Distribution of Victim Ages - Baltimore 2025",
    x = "Victim Age",
    y = "Number of Victims"
  )

print(histogram_plot)


# TABULAR HISTOGRAM


age_table <- clean_data %>%
  mutate(age_group = cut(Age, breaks = seq(0, 100, by = 5))) %>%
  count(age_group)

cat("\nHistogram Data (Age Group):\n")
print(age_table)