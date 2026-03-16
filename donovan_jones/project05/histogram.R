library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

cat("Downloading data...\n")

page <- read_html(url)

tables <- html_table(page, fill = TRUE)

data <- bind_rows(tables)

colnames(data)[1] <- "Raw"

data <- data %>%
  mutate(
    Age = str_extract(Raw, ",\\s*\\d{1,3}") %>%
      str_remove(",") %>%
      as.numeric()
  ) %>%
  filter(!is.na(Age))

cat("Total victims with valid age:", nrow(data), "\n\n")

data <- data %>%
  mutate(
    AgeGroup = cut(Age, breaks = seq(0, 100, by = 10), right = FALSE)
  )

hist_table <- data %>%
  count(AgeGroup) %>%
  arrange(AgeGroup)

cat("Homicides by Age Group (2025)\n")
print(hist_table)

p <- ggplot(data, aes(x = Age)) +
  geom_histogram(binwidth = 5) +
  labs(
    title = "Distribution of Baltimore Homicide Victim Ages (2025)",
    x = "Age",
    y = "Number of Victims"
  )

ggsave("histogram.png", plot = p)

cat("\nHistogram saved as histogram.png\n")