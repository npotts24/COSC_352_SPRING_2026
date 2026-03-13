#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
  library(readr)
})

url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
out_png <- "histogram.png"

is_numeric_case_no <- function(x) {
  str_detect(x, "^\\s*\\d+\\s*$")
}

make_age_bins <- function(age_vec, bin_size = 10, max_age = 100) {
  breaks <- c(seq(0, max_age, by = bin_size), Inf)
  labels <- c(
    paste0(seq(0, max_age - bin_size, by = bin_size), "-", seq(bin_size - 1, max_age - 1, by = bin_size)),
    paste0(max_age, "+")
  )
  cut(age_vec, breaks = breaks, right = FALSE, labels = labels, include.lowest = TRUE)
}

page <- read_html(url)

tables <- page %>% html_elements("table")
if (length(tables) == 0) {
  stop("No HTML tables found on the page. The page layout may have changed.")
}

raw_tbl <- tables[[1]] %>% html_table(fill = TRUE)

if (length(raw_tbl) == 0) {
  stop("Table parsed but returned empty. The table structure may have changed.")
}

df <- raw_tbl[[1]]

names(df) <- names(df) %>%
  str_replace_all("\\s+", " ") %>%
  str_trim()

names(df) <- make.names(names(df), unique = TRUE)

col_no   <- names(df)[str_detect(names(df), "^No\\.?$|^No\\.$|^No$|^No\\.$|^No\\._?$|^No\\..*$")][1]
col_date <- names(df)[str_detect(names(df), "Date")][1]
col_name <- names(df)[str_detect(names(df), "Name")][1]
col_age  <- names(df)[str_detect(names(df), "Age")][1]

if (any(is.na(c(col_no, col_date, col_name, col_age)))) {
  message("Columns found: ", paste(names(df), collapse = ", "))
  stop("Could not reliably detect required columns (No/Date/Name/Age).")
}

clean <- df %>%
  mutate(
    CaseNo = as.character(.data[[col_no]]),
    DateDiedRaw = as.character(.data[[col_date]]),
    Name = as.character(.data[[col_name]]),
    AgeRaw = as.character(.data[[col_age]])
  ) %>%
  filter(!is.na(CaseNo), is_numeric_case_no(CaseNo)) %>%
  mutate(
    CaseNo = str_trim(CaseNo),
    DateDied = suppressWarnings(mdy(DateDiedRaw)),
    Age = suppressWarnings(parse_number(AgeRaw))
  ) %>%
  filter(!is.na(Age), Age >= 0, Age <= 120)

if (nrow(clean) == 0) {
  stop("After cleaning, no usable rows remained. Check parsing/filters.")
}

clean <- clean %>%
  mutate(AgeBin = make_age_bins(Age, bin_size = 10, max_age = 100))

hist_table <- clean %>%
  count(AgeBin, name = "Count") %>%
  arrange(AgeBin)

cat("\n=== Tabular Histogram: Victim Ages (10-year bins) — 2025 Baltimore City Homicides ===\n")
print(hist_table, n = Inf)
cat("\nTotal records used (after cleaning): ", nrow(clean), "\n\n", sep = "")

p <- ggplot(clean, aes(x = Age)) +
  geom_histogram(binwidth = 5, boundary = 0, closed = "left") +
  labs(
    title = "Baltimore City Homicide Victim Ages (2025)",
    subtitle = "Histogram uses 5-year bins; table printed uses 10-year bins (cleaned numeric-case rows only)",
    x = "Victim Age (years)",
    y = "Number of Homicides"
  ) +
  theme_minimal()

ggsave(out_png, plot = p, width = 10, height = 6, dpi = 150)

cat("Saved plot to: ", out_png, "\n", sep = "")