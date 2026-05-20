# histogram.R

library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Reading data from website...\n")

# Read webpage
page <- read_html(url)

# Extract tables
tables <- html_table(page)

# Use first table
data <- tables[[1]]

cat("Rows scraped:", nrow(data), "\n\n")

# First column usually contains victim info (name, age, etc.)
victim_info <- data[[1]]

# --- Robust age extraction ---
# Extract all numbers from each row
all_numbers <- str_extract_all(victim_info, "\\d+")

# Flatten list to vector
all_numbers <- unlist(all_numbers)

# Convert to numeric
all_numbers <- as.numeric(all_numbers)

# Keep only realistic human ages
ages <- all_numbers[all_numbers >= 1 & all_numbers <= 100]

# Debug: show first 20 ages (optional)
# print(head(ages, 20))

# --- Create histogram ---
hist_result <- hist(ages, breaks=seq(0, 100, 5), plot=FALSE)

# Create readable age ranges
age_ranges <- paste(
  hist_result$breaks[-length(hist_result$breaks)],
  hist_result$breaks[-1],
  sep="-"
)

# Make output table
output_table <- data.frame(
  AgeRange = age_ranges,
  Count = hist_result$counts
)

# Print tabular histogram to stdout
cat("Victim Age Distribution (2025)\n")
cat("---------------------------------\n")
print(output_table, row.names=FALSE)

# Create histogram plot
plot <- ggplot(data.frame(Age=ages), aes(x=Age)) +
  geom_histogram(binwidth=5, fill="blue", color="black") +
  labs(
    title="Baltimore Homicide Victim Ages (2025)",
    x="Age",
    y="Number of Victims"
  ) +
  theme_minimal()

# Save image
ggsave("histogram.png", plot)

cat("\nSaved histogram.png\n")