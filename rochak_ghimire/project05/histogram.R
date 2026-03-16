# histogram.R

# Load required packages
library(rvest)
library(dplyr)
library(stringr)
library(lubridate)
library(ggplot2)
library(tidyr)
library(purrr)

# Function to scrape a year from the blog
scrape_year <- function(year) {
  url <- paste0("https://chamspage.blogspot.com/", year, "/01/", year, "-baltimore-city-homicide-list.html")
  message("Scraping: ", url)
  
  page <- try(read_html(url), silent = TRUE)
  if(inherits(page, "try-error")) {
    message("Failed to load year: ", year)
    return(NULL)
  }
  
  tables <- html_nodes(page, "table")
  if(length(tables) == 0) return(NULL)
  
  df <- html_table(tables[[1]], fill = TRUE)
  
  # Detect age column automatically
  age_col <- grep("Age|AGE|X1", names(df), value = TRUE)[1]
  if(is.null(age_col)) {
    message("No Age column found in year: ", year)
    return(NULL)
  }
  
  df <- df %>% select(all_of(age_col))
  names(df) <- "Age"
  
  # Clean Age column: keep only numeric values
  df$Age <- as.numeric(str_extract(df$Age, "\\d+"))
  
  df <- df %>% filter(!is.na(Age))
  return(df)
}

# Scrape multiple years
years <- 2023:2025
all_data <- map_dfr(years, scrape_year)

if(nrow(all_data) == 0) {
  stop("Error: No data scraped successfully.")
}

# Create age groups: 0-9, 10-19, 20-29, ...
all_data$AgeGroup <- cut(all_data$Age, breaks = seq(0, 100, by = 10), right = FALSE,
                         labels = c("0-9","10-19","20-29","30-39","40-49","50-59",
                                    "60-69","70-79","80-89","90-99"))

# Count victims in each age group
age_counts <- all_data %>%
  filter(!is.na(AgeGroup)) %>%
  count(AgeGroup)

# Display tabular histogram
message("\n--- Tabular Histogram of Victim Ages ---")
print(age_counts)

# Plot histogram
p <- ggplot(age_counts, aes(x=AgeGroup, y=n, fill=AgeGroup)) +
  geom_bar(stat="identity", color="black") +
  labs(title="Baltimore Homicide Victim Age Distribution",
       x="Age Group",
       y="Number of Victims") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle=45, hjust=1),
        legend.position="none",
        plot.title = element_text(hjust = 0.5, size=16, face="bold"))

# Save the histogram as PNG
ggsave("histogram.png", plot = p, width = 8, height = 6)
message("Histogram saved as histogram.png\nDone.")
