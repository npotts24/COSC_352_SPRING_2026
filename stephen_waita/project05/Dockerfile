# ---------------------------
# ONE-FILE DOCKERIZED SOLUTION
# Project 5 – Data Processing Capstone #1
# ---------------------------

FROM rocker/r-base:4.4.1

# System deps for rvest/xml/curl and HTTPS
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install R packages
RUN R -e "install.packages(c('rvest','dplyr','stringr','lubridate','ggplot2','readr','tidyr'), repos='https://cloud.r-project.org')"

# Write the entire R program into the image (no separate .R file needed)
RUN cat > /app/main.R << 'RSCRIPT'
#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(ggplot2)
  library(readr)
  library(tidyr)
})

URL <- "https://champspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

message("Fetching: ", URL)

fetch_page <- function(url, tries = 3, sleep_sec = 2) {
  for (i in seq_len(tries)) {
    ok <- TRUE
    page <- tryCatch(read_html(url), error = function(e) { ok <<- FALSE; NULL })
    if (ok && !is.null(page)) return(page)
    Sys.sleep(sleep_sec)
  }
  stop("Failed to fetch page after retries.")
}

page <- fetch_page(URL)

tables <- page |>
  html_elements("table") |>
  lapply(\(t) html_table(t, fill = TRUE))

if (length(tables) == 0) stop("No <table> elements found on the page (structure may have changed).")

raw <- bind_rows(lapply(seq_along(tables), function(i) {
  df <- tables[[i]]
  df$.__table_index <- i
  df
}), .id = ".__row_source") |>
  mutate(across(everything(), \(x) if (is.character(x)) str_squish(x) else x))

colnames_lower <- tolower(names(raw))

find_col <- function(keywords) {
  idx <- which(sapply(colnames_lower, \(nm) any(str_detect(nm, keywords))))
  if (length(idx) == 0) return(NA_integer_)
  idx[[1]]
}

date_idx <- find_col(c("date", "dod", "death"))

if (is.na(date_idx)) {
  date_like_score <- sapply(raw, function(col) {
    if (!is.character(col)) return(0)
    mean(str_detect(col, "\\b\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}\\b|\\b[A-Za-z]{3,9}\\s+\\d{1,2}\\b"), na.rm = TRUE)
  })
  date_idx <- which.max(date_like_score)
  if (length(date_idx) == 0 || date_like_score[[date_idx]] < 0.10) stop("Couldn't identify a date column reliably.")
}

date_col <- names(raw)[[date_idx]]

clean <- raw |>
  filter(if_any(everything(), \(x) !is.na(x) & x != "")) |>
  filter(str_detect(.data[[date_col]],
                    "\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}|[A-Za-z]{3,9}\\s+\\d{1,2}")) |>
  mutate(
    date_raw = .data[[date_col]],
    date = parse_date_time(
      date_raw,
      orders = c("mdy", "m/d/y", "m/d/Y", "mdY", "b d Y", "B d Y", "b d", "B d"),
      tz = "America/New_York"
    ),
    date = if_else(is.na(year(date)) | year(date) < 1900, update(date, year = 2025), date),
    month = month(date, label = TRUE, abbr = TRUE)
  )

monthly <- clean |>
  filter(!is.na(date)) |>
  count(month, sort = FALSE) |>
  complete(month = factor(month.abb, levels = month.abb), fill = list(n = 0)) |>
  arrange(match(as.character(month), month.abb)) |>
  mutate(month = factor(as.character(month), levels = month.abb))

cat("\n=== Baltimore City Homicides (2025) — Count by Month ===\n")
print(monthly, row.names = FALSE)
cat("\nTotal rows parsed (after cleaning): ", nrow(clean), "\n", sep = "")
cat("Total with parsed dates: ", sum(!is.na(clean$date)), "\n\n", sep = "")

p <- ggplot(monthly, aes(x = month, y = n)) +
  geom_col() +
  labs(
    title = "Baltimore City Homicides (2025): Counts by Month",
    x = "Month",
    y = "Number of homicides"
  ) +
  theme_minimal(base_size = 12)

ggsave("histogram.png", plot = p, width = 10, height = 6, dpi = 160)

message("Saved: histogram.png")
RSCRIPT

RUN chmod +x /app/main.R

# Write README into the image (no separate README needed)
RUN cat > /app/README.md << 'README'
# Project 5 — Data Processing Capstone #1 (Dockerized R)

## What this container does
- Scrapes the 2025 Baltimore City Homicide List page (champspage.blogspot.com)
- Cleans messy HTML table data into a structured data frame
- Computes a histogram-style statistic: **homicides by month**
- Prints the table to stdout and saves a bar-style histogram as `histogram.png`

## Why this statistic
Counting homicides per month quickly shows whether there’s seasonality (spikes in certain months)
instead of an even pattern across the year.

## Cleaning decisions / assumptions
- The page can contain multiple tables and repeated headers, so the script reads all tables and stacks them.
- It filters rows that look like they contain a date.
- Dates appear in multiple formats, so multiple parse formats are attempted.
- If a row has a date like “Jan 3” without a year, the script assumes **2025** (since this is the 2025 list).

## Run instructions (grader-friendly)
From the folder that contains this Dockerfile:

1) Build:
   docker build -t bmore-homicides .

2) Run (saves histogram.png to your current folder):
   docker run --rm -v "%cd%:/app" -w /app bmore-homicides
README

# Default command: run script
CMD ["Rscript", "/app/main.R"]