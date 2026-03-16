#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
  library(readr)
})

URL_2025 <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
OUT_AGE_PNG <- "histogram.png"
OUT_METHOD_PNG <- "histogram_by_method.png"

safe_read_html <- function(url) {
  tryCatch(
    read_html(url),
    error = function(e) {
      message("ERROR: Failed to fetch page: ", url)
      message("Reason: ", conditionMessage(e))
      quit(status = 2)
    }
  )
}

# Normalize names into safe, non-empty, unique identifiers
make_safe_names <- function(x) {
  x <- as.character(x)
  x <- str_squish(x)
  x <- str_replace_all(x, "\\s+", "_")
  x <- str_replace_all(x, "[^A-Za-z0-9_]", "")
  x <- tolower(x)
  x[x == "" | is.na(x)] <- "x"
  make.unique(x, sep = "_")
}

# Find which row looks like a header (contains "date" and "age")
find_header_row <- function(df) {
  if (nrow(df) == 0) return(NA_integer_)
  maxr <- min(25, nrow(df))
  for (i in 1:maxr) {
    rowtxt <- tolower(paste(as.character(df[i, ]), collapse = " "))
    if (str_detect(rowtxt, "\\bdate\\b") && str_detect(rowtxt, "\\bage\\b")) {
      return(i)
    }
  }
  NA_integer_
}

# Choose the best table: header row present + many rows
pick_best_table <- function(tables) {
  scores <- sapply(tables, function(df) {
    hr <- find_header_row(df)
    has_header <- !is.na(hr)
    rows <- nrow(df)
    score <- 0
    if (has_header) score <- score + 100
    score <- score + min(rows, 400)
    score
  })
  which.max(scores)
}

# Flexible date parse: mdy first, then my
parse_date_flex <- function(x) {
  x <- str_squish(as.character(x))
  out <- suppressWarnings(mdy(x))
  needs_my <- is.na(out) & str_detect(x, "^[0-9]{1,2}/[0-9]{4}$")
  out[needs_my] <- suppressWarnings(my(x[needs_my]))
  out
}

# Keyword-based method inference (approximate)
derive_method <- function(text) {
  t <- str_to_lower(text)
  case_when(
    str_detect(t, "\\bshoot") ~ "Shooting",
    str_detect(t, "\\bstabb") ~ "Stabbing",
    str_detect(t, "\\bstrangl") ~ "Strangulation",
    str_detect(t, "\\bbeaten\\b|\\bblunt\\b") ~ "Blunt force",
    str_detect(t, "\\bvehicle\\b|\\bcar\\b|\\bhit\\b") ~ "Vehicle",
    TRUE ~ "Other/Unknown"
  )
}

# -----------------------------
# Scrape tables
# -----------------------------
page <- safe_read_html(URL_2025)

tables <- page |>
  html_elements("table") |>
  lapply(\(t) html_table(t, fill = TRUE))

if (length(tables) == 0) {
  message("ERROR: No HTML tables found on the page. The page structure may have changed.")
  quit(status = 3)
}

best_i <- pick_best_table(tables)
raw <- tables[[best_i]]

header_row <- find_header_row(raw)
if (is.na(header_row)) {
  message("ERROR: Could not locate a header row containing 'Date' and 'Age'.")
  message("Best table had ", nrow(raw), " rows and ", ncol(raw), " cols.")
  quit(status = 4)
}

# Use detected header row as column names; data starts after it
hdr <- raw[header_row, , drop = TRUE]
raw2 <- raw[(header_row + 1):nrow(raw), , drop = FALSE]
names(raw2) <- make_safe_names(hdr)

# Map key columns by name patterns
nms <- names(raw2)
col_date <- nms[str_detect(nms, "date")]
col_age  <- nms[str_detect(nms, "^age$|_age$|\\bage\\b")]
col_name <- nms[str_detect(nms, "^name$|victim|\\bname\\b")]

col_date <- if (length(col_date) > 0) col_date[1] else NA_character_
col_age  <- if (length(col_age)  > 0) col_age[1]  else NA_character_
col_name <- if (length(col_name) > 0) col_name[1] else NA_character_

if (any(is.na(c(col_date, col_age, col_name)))) {
  message("ERROR: Could not detect required columns after header normalization.")
  message("Columns found: ", paste(names(raw2), collapse = ", "))
  quit(status = 5)
}

# Build cleaned df + keep row_text for method inference
df <- raw2 |>
  mutate(row_text = apply(raw2, 1, \(r) paste(na.omit(as.character(r)), collapse = " "))) |>
  transmute(
    date_raw = .data[[col_date]],
    name_raw = .data[[col_name]],
    age_raw  = .data[[col_age]],
    row_text = row_text
  ) |>
  mutate(
    date_raw = str_squish(as.character(date_raw)),
    name_raw = str_squish(as.character(name_raw)),
    age_raw  = str_squish(as.character(age_raw)),
    row_text = str_squish(as.character(row_text)),
    date_died = parse_date_flex(date_raw),
    age = suppressWarnings(parse_number(age_raw))
  ) |>
  # drop bad rows
  filter(!is.na(date_died), !is.na(age)) |>
  filter(age >= 0, age <= 110) |>
  filter(year(date_died) == 2025)

if (nrow(df) == 0) {
  message("ERROR: After cleaning, no 2025 rows with valid ages were found.")
  quit(status = 6)
}

# -----------------------------
# Histogram 1: Age distribution + tabular output
# -----------------------------
bin_width <- 5
min_age <- floor(min(df$age, na.rm = TRUE) / bin_width) * bin_width
max_age <- ceiling(max(df$age, na.rm = TRUE) / bin_width) * bin_width
starts  <- seq(min_age, max_age, by = bin_width)

hist_age_tbl <- df |>
  mutate(bin_start = floor(age / bin_width) * bin_width) |>
  count(bin_start, name = "count") |>
  arrange(bin_start)

# Ensure all bins appear (count 0) without tidyr
all_bins <- tibble(bin_start = starts)
hist_age_tbl <- all_bins |>
  left_join(hist_age_tbl, by = "bin_start") |>
  mutate(
    count = ifelse(is.na(count), 0L, count),
    bin_end = bin_start + bin_width - 1L
  ) |>
  select(bin_start, bin_end, count)

cat("\nBaltimore City Homicides (2025) — Victim Age Histogram (5-year bins)\n")
cat("Source: ", URL_2025, "\n\n", sep = "")
print(hist_age_tbl, n = nrow(hist_age_tbl))
cat("\nTotal records used (2025 with valid age): ", nrow(df), "\n\n", sep = "")

p_age <- ggplot(df, aes(x = age)) +
  geom_histogram(binwidth = bin_width, boundary = 0, closed = "left") +
  labs(
    title = "Baltimore City Homicide Victims (2025): Age Distribution",
    subtitle = "Histogram of victim ages (5-year bins) scraped from Cham's blog",
    x = "Victim age (years)",
    y = "Number of victims"
  ) +
  theme_minimal(base_size = 12)

ggsave(filename = OUT_AGE_PNG, plot = p_age, width = 10, height = 6, dpi = 150)
cat("Saved plot to: ", normalizePath(OUT_AGE_PNG, winslash = "/", mustWork = FALSE), "\n", sep = "")

# -----------------------------
# Histogram 2: Method (shooting vs stabbing etc.) + tabular output
# -----------------------------
df_method <- df |>
  mutate(method = derive_method(row_text))

method_tbl <- df_method |>
  count(method, name = "count") |>
  arrange(desc(count))

cat("\nBaltimore City Homicides (2025) — Method Breakdown (keyword-based)\n")
cat("Source: ", URL_2025, "\n")
cat("Note: Method is inferred from keywords in the row text, so it is approximate.\n\n")
print(method_tbl, n = nrow(method_tbl))

p_method <- ggplot(method_tbl, aes(x = reorder(method, -count), y = count)) +
  geom_col() +
  labs(
    title = "Baltimore City Homicides (2025): Method Breakdown",
    subtitle = "Method inferred from keywords in table row text (approximate)",
    x = "Method",
    y = "Number of homicides"
  ) +
  theme_minimal(base_size = 12)

ggsave(filename = OUT_METHOD_PNG, plot = p_method, width = 10, height = 6, dpi = 150)
cat("\nSaved plot to: ", normalizePath(OUT_METHOD_PNG, winslash = "/", mustWork = FALSE), "\n", sep = "")