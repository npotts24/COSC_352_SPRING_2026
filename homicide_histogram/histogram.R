#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
  library(tidyr)
})

YEAR_URLS <- list(
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
)

OUT_PNG <- "homicides_by_month.png"

safe_read_html <- function(url) {
  tryCatch(
    read_html(url),
    error = function(e) {
      message("ERROR: Failed to download HTML from: ", url)
      message("Reason: ", conditionMessage(e))
      quit(status = 1)
    }
  )
}

normalize_names <- function(nms) {
  nms %>%
    str_replace_all("\\s+", " ") %>%
    str_trim() %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_replace_all("_+", "_") %>%
    str_replace_all("^_|_$", "")
}

extract_homicide_table <- function(doc) {
  tables <- doc %>% html_elements("table")
  if (length(tables) == 0) stop("No HTML tables found on the page.")
  df <- tables[[1]] %>% html_table(fill = TRUE)
  names(df) <- normalize_names(names(df))
  df <- df %>% select(where(~ !all(is.na(.x) | str_trim(as.character(.x)) == "")))
  df
}

detect_date_col <- function(df) {
  nms <- names(df)

  candidate <- nms[str_detect(nms, "date")]
  if (length(candidate) >= 1) return(candidate[1])

  date_regex <- "^\\d{2}/\\d{2}/\\d{2}$"
  scores <- sapply(nms, function(col) {
    vals <- as.character(df[[col]])
    vals <- str_squish(vals)
    mean(str_detect(vals, date_regex), na.rm = TRUE)
  })

  best <- nms[which.max(scores)]
  if (length(best) == 0 || is.na(scores[best]) || scores[best] < 0.05) {
    stop("Could not detect a date column. Table format may have changed.")
  }
  best
}

clean_homicide_df <- function(df, year_label) {
  df <- df %>% mutate(across(everything(), ~ ifelse(is.na(.x), NA_character_, as.character(.x))))
  date_col <- detect_date_col(df)

  df %>%
    mutate(date_raw = str_squish(.data[[date_col]])) %>%
    filter(str_detect(date_raw, "^\\d{2}/\\d{2}/\\d{2}$")) %>%
    mutate(
      year = as.integer(year_label),
      date = mdy(date_raw),
      month_num = month(date),
      month = month(date, label = TRUE, abbr = TRUE)
    ) %>%
    filter(!is.na(date))
}

all_rows <- list()

for (yr in names(YEAR_URLS)) {
  url <- YEAR_URLS[[yr]]
  message("Scraping ", yr, " from: ", url)
  doc <- safe_read_html(url)
  raw_tbl <- extract_homicide_table(doc)
  cleaned <- clean_homicide_df(raw_tbl, yr)
  all_rows[[yr]] <- cleaned
}

data <- bind_rows(all_rows)

if (nrow(data) == 0) {
  message("ERROR: After cleaning, no homicide rows were found. HTML structure may have changed.")
  quit(status = 1)
}

hist_tbl <- data %>%
  count(year, month_num, month, name = "homicides") %>%
  arrange(year, month_num) %>%
  mutate(month = as.character(month)) %>%
  select(year, month, homicides)

message("\n=== Tabular Histogram: Baltimore City Homicides by Month (Cham's Blog) ===")
print(hist_tbl, row.names = FALSE)

p <- ggplot(data, aes(x = month_num)) +
  geom_histogram(binwidth = 1, boundary = 0.5, closed = "left") +
  scale_x_continuous(breaks = 1:12, labels = month.abb, limits = c(0.5, 12.5)) +
  facet_wrap(~year, ncol = 1) +
  labs(
    title = "Baltimore City Homicides by Month (Cham's Blog)",
    x = "Month",
    y = "Number of homicides"
  ) +
  theme_minimal(base_size = 12)

ggsave(OUT_PNG, plot = p, width = 10, height = 7, dpi = 150)

message("\nSaved plot to: ", OUT_PNG)
message("Rows scraped (after cleaning): ", nrow(data))
message("Years included: ", paste(sort(unique(data$year)), collapse = ", "))
