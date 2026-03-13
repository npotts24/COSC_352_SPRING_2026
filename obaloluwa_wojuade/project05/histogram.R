suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
  library(tidyr)
})

years_to_scrape <- 2022:2025

build_year_url <- function(year) {
  sprintf("https://chamspage.blogspot.com/%d/01/%d-baltimore-city-homicide-list.html", year, year)
}

normalize_colnames <- function(x) {
  x %>%
    str_trim() %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_replace_all("^_+|_+$", "")
}

promote_first_row_if_header <- function(df) {
  if (nrow(df) == 0 || ncol(df) == 0) return(df)

  first_row <- as.character(unlist(df[1, ], use.names = FALSE))
  first_row[is.na(first_row)] <- ""
  first_row_norm <- normalize_colnames(first_row)
  header_hits <- sum(str_detect(first_row_norm, "age|victim|name|date|method|camera|closed"), na.rm = TRUE)

  if (header_hits >= 2) {
    names(df) <- make.names(first_row_norm, unique = TRUE)
    df <- df[-1, , drop = FALSE]
  }

  df
}

extract_numeric_age <- function(text_col) {
  age <- str_extract(text_col, "\\b(1[01][0-9]|120|[1-9]?[0-9])\\b")
  as.integer(age)
}

parse_homicide_tables <- function(url) {
  page <- read_html(url)
  tables <- html_elements(page, "table")

  if (length(tables) == 0) {
    stop("No HTML tables were found at the source URL.")
  }

  parsed <- lapply(seq_along(tables), function(i) {
    raw <- html_table(tables[[i]], fill = TRUE)
    raw <- promote_first_row_if_header(raw)
    names(raw) <- normalize_colnames(names(raw))
    raw$source_table_id <- i
    raw
  })

  bind_rows(parsed)
}

find_column <- function(df, patterns) {
  cols <- names(df)
  match_idx <- which(str_detect(cols, patterns))
  if (length(match_idx) == 0) return(NA_character_)
  cols[match_idx[1]]
}

parse_year_data <- function(year) {
  source_url <- build_year_url(year)
  out <- tryCatch({
    data <- parse_homicide_tables(source_url)
    data$year <- year
    data$source_url <- source_url
    data
  }, error = function(e) {
    message(sprintf("Skipping year %d (%s)", year, conditionMessage(e)))
    NULL
  })

  out
}

yearly_tables <- lapply(years_to_scrape, parse_year_data)
raw_data <- bind_rows(yearly_tables)

if (nrow(raw_data) == 0) {
  stop("No data could be scraped for any requested year.")
}

age_col <- find_column(raw_data, "(^|_)age($|_)|victim_age")
victim_col <- find_column(raw_data, "victim|name")
date_col <- find_column(raw_data, "date|death|incident")
method_col <- find_column(raw_data, "method|weapon|cause")
camera_col <- find_column(raw_data, "camera|cctv")
closed_col <- find_column(raw_data, "closed|status")

clean_data <- raw_data

if (!is.na(age_col)) {
  clean_data <- clean_data %>% mutate(age = suppressWarnings(as.integer(.data[[age_col]])))
} else if (!is.na(victim_col)) {
  clean_data <- clean_data %>% mutate(age = extract_numeric_age(.data[[victim_col]]))
} else {
  stop("Could not locate an age field (direct age column or victim/name column with embedded age).")
}

if (!is.na(date_col)) {
  clean_data <- clean_data %>%
    mutate(date_of_death = suppressWarnings(parse_date_time(.data[[date_col]], orders = c("mdy", "m/d/y", "B d, Y", "b d, Y", "Y-m-d"))))
} else {
  stop("Could not locate a date field for month-based histogram analysis.")
}

if (!is.na(method_col)) {
  clean_data <- clean_data %>% mutate(method = str_squish(as.character(.data[[method_col]])))
}

if (!is.na(camera_col)) {
  clean_data <- clean_data %>% mutate(camera_nearby = str_squish(as.character(.data[[camera_col]])))
}

if (!is.na(closed_col)) {
  clean_data <- clean_data %>% mutate(case_closed = str_squish(as.character(.data[[closed_col]])))
}

month_levels <- month.abb

month_data <- clean_data %>%
  filter(!is.na(date_of_death)) %>%
  mutate(
    year = as.integer(year),
    month_num = month(date_of_death),
    month_label = factor(month(date_of_death, label = TRUE, abbr = TRUE), levels = month_levels, ordered = TRUE)
  )

if (nrow(month_data) == 0) {
  stop("No valid dates were parsed after cleaning.")
}

hist_table <- month_data %>%
  count(year, month_label, name = "homicides") %>%
  complete(year = sort(unique(month_data$year)), month_label = factor(month_levels, levels = month_levels, ordered = TRUE), fill = list(homicides = 0L)) %>%
  arrange(year, month_label)

cat("=== Baltimore Homicides: Monthly Distribution by Year (2022-2025) ===\n")
cat("Sources:\n")
for (y in sort(unique(month_data$year))) {
  cat("-", build_year_url(y), "\n")
}
cat("\n")
print(hist_table, n = nrow(hist_table))

cat("\nRecords with valid date:", nrow(month_data), "\n")

age_summary <- clean_data %>%
  mutate(age = suppressWarnings(as.integer(age))) %>%
  filter(!is.na(age), age >= 0, age <= 120) %>%
  group_by(year) %>%
  summarise(median_age = median(age), valid_age_records = n(), .groups = "drop") %>%
  arrange(year)

if (nrow(age_summary) > 0) {
  cat("\nMedian victim age by year (supporting context):\n")
  print(age_summary, n = nrow(age_summary))
}

plot_obj <- ggplot(month_data, aes(x = month_num, fill = factor(year))) +
  geom_histogram(binwidth = 1, boundary = 0.5, color = "white", alpha = 0.45, position = "identity") +
  scale_x_continuous(breaks = 1:12, labels = month.abb) +
  labs(
    title = "Baltimore City Homicides (2022-2025): Monthly Distribution",
    subtitle = "Overlaid histogram highlights seasonal concentration and year-to-year shifts",
    x = "Month",
    y = "Number of homicides",
    fill = "Year"
  ) +
  theme_minimal(base_size = 12)

ggsave(
  filename = "homicide_month_histogram_2022_2025.png",
  plot = plot_obj,
  width = 11,
  height = 6,
  dpi = 150
)

cat("\nHistogram image saved to: homicide_month_histogram_2022_2025.png\n")
