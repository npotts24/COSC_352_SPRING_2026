library(rvest)
library(dplyr)
library(lubridate)

scrape_homicide_data <- function() {
  urls <- c(
    "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
    "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
    "2023" = "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html"
  )

  all_records <- data.frame()

  for (year in names(urls)) {
    url <- urls[year]
    message("Scraping ", year, " homicide data from ", url)

    page <- read_html(url)
    tables <- page %>% html_table()

    for (table in tables) {
      if (ncol(table) >= 7) {
        colnames(table) <- c("date", "victim", "age", "race", "sex", "location", "method")
        table$year <- as.integer(year)
        table$date <- mdy(table$date, quiet = TRUE)
        table$age <- as.integer(table$age)
        all_records <- bind_rows(all_records, table)
      }
    }
  }

  return(all_records)
}

# Scrape on load
homicide_data <- scrape_homicide_data()