library(rvest)
library(dplyr)
library(stringr)
library(lubridate)
library(ggplot2)

scrape_baltimore_data <- function(url) {
  tryCatch({
    page <- read_html(url)
    table_data <- page %>% html_node("table") %>% html_table(fill = TRUE)
    return(table_data)
  }, error = function(e) {
    message(paste("Error scraping:", url))
    return(NULL)
  })
}

urls <- c(
  "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html"
)

raw_data <- lapply(urls, scrape_baltimore_data) %>% bind_rows()

if(ncol(raw_data) >= 3) {
  colnames(raw_data)[1:3] <- c("Number", "Name_Age", "Date")
}

cleaned_data <- raw_data %>%
  mutate(Date = mdy(Date)) %>%
  filter(!is.na(Date)) %>%
  mutate(Month = month(Date, label = TRUE, abbr = FALSE))

histo_table <- cleaned_data %>%
  group_by(Month) %>%
  summarise(Count = n()) %>%
  arrange(Month)

cat("\n--- Tabular Histogram: Homicides by Month ---\n")
print(as.data.frame(histo_table), row.names = FALSE)

p <- ggplot(cleaned_data, aes(x = Month)) +
  geom_bar(fill = "steelblue", color = "black") +
  theme_minimal() +
  labs(title = "Baltimore City Homicides by Month (2024-2025)",
       x = "Month",
       y = "Frequency")

ggsave("histogram.png", plot = p, width = 8, height = 6)
cat("\nVisual histogram saved to histogram.png\n")