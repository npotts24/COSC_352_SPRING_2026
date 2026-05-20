# histogram.R
# Baltimore City Homicide Data Analysis
# Scrapes 2024 and 2025 homicide data from chamspage.blogspot.com,
# cleans the data, and produces a histogram of homicides by month
# (comparing 2024 vs 2025 side-by-side). Also prints a tabular summary.

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(ggplot2)
  library(lubridate)
})

# ── helpers ────────────────────────────────────────────────────────────────────

# Parse a single year's table from the blog
scrape_year <- function(url, year_label) {
  message("Fetching: ", url)

  page <- tryCatch(
    read_html(url),
    error = function(e) {
      message("ERROR fetching ", url, ": ", conditionMessage(e))
      return(NULL)
    }
  )
  if (is.null(page)) return(NULL)

  # The homicide table is the first (and only major) table on the page
  tables <- html_nodes(page, "table")
  if (length(tables) == 0) {
    message("No tables found on page: ", url)
    return(NULL)
  }

  # Grab the first table (the main homicide list)
  raw <- html_table(tables[[1]], fill = TRUE, header = FALSE)

  # Find the header row (contains "Date Died" or "Date")
  header_row <- which(apply(raw, 1, function(r)
    any(grepl("Date", r, ignore.case = TRUE))))[1]

  if (is.na(header_row)) header_row <- 1

  # Rename columns based on what we find in the header row
  col_names <- as.character(raw[header_row, ])
  col_names <- str_trim(col_names)
  col_names[col_names == ""] <- paste0("V", seq_along(col_names[col_names == ""]))

  # Data starts one row below header
  df <- raw[(header_row + 1):nrow(raw), ]
  names(df) <- make.unique(col_names)

  # Identify the date column ("Date Died", "Date", etc.)
  date_col <- names(df)[grepl("date|died", names(df), ignore.case = TRUE)][1]
  if (is.na(date_col)) date_col <- names(df)[2]   # fall back to second column

  # Identify age column
  age_col <- names(df)[grepl("^age$", names(df), ignore.case = TRUE)][1]

  # Identify case-closed column
  closed_col <- names(df)[grepl("closed", names(df), ignore.case = TRUE)][1]

  # Identify CCTV column
  cctv_col <- names(df)[grepl("camera|cctv|surveillance", names(df), ignore.case = TRUE)][1]

  # Identify method / notes column
  notes_col <- names(df)[grepl("notes", names(df), ignore.case = TRUE)][1]

  # Build tidy data frame
  out <- df %>%
    mutate(
      year        = year_label,
      date_raw    = str_trim(.data[[date_col]]),
      age_raw     = if (!is.na(age_col)) str_trim(.data[[age_col]]) else NA_character_,
      closed_raw  = if (!is.na(closed_col)) str_trim(.data[[closed_col]]) else NA_character_,
      cctv_raw    = if (!is.na(cctv_col))  str_trim(.data[[cctv_col]])  else NA_character_,
      notes_raw   = if (!is.na(notes_col)) str_trim(.data[[notes_col]]) else NA_character_
    ) %>%
    select(year, date_raw, age_raw, closed_raw, cctv_raw, notes_raw)

  out
}

# ── scrape 2024 and 2025 ──────────────────────────────────────────────────────

url_2025 <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
url_2024 <- "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html"

raw_2025 <- scrape_year(url_2025, 2025)
raw_2024 <- scrape_year(url_2024, 2024)

all_raw <- bind_rows(raw_2025, raw_2024)

# ── clean dates ───────────────────────────────────────────────────────────────

# Dates appear as MM/DD/YY  (e.g. "01/09/25") or MM/DD/YYYY or MM/YYYY
parse_date <- function(d) {
  d <- str_trim(d)
  # Try MM/DD/YY
  parsed <- suppressWarnings(mdy(d))
  if (!is.na(parsed)) return(parsed)
  # Try MM/DD/YYYY
  parsed <- suppressWarnings(mdy(d))
  if (!is.na(parsed)) return(parsed)
  # MM/YYYY  (incomplete dates – treat as 1st of month)
  if (grepl("^\\d{1,2}/\\d{4}$", d)) {
    return(suppressWarnings(mdy(paste0(d, "/01"))))
  }
  NA_Date_
}

all_clean <- all_raw %>%
  filter(!is.na(date_raw), date_raw != "") %>%
  rowwise() %>%
  mutate(
    date       = parse_date(date_raw),
    month      = if (!is.na(date)) month(date, label = TRUE, abbr = TRUE) else NA,
    month_num  = if (!is.na(date)) month(date) else NA_integer_
  ) %>%
  ungroup() %>%
  # Drop placeholder / header rows that leaked through
  filter(!is.na(date), !grepl("Date Died|No\\.", date_raw, ignore.case = TRUE)) %>%
  # Keep only rows whose date year roughly matches the stated year
  filter(year(date) %in% c(2024, 2025)) %>%
  mutate(
    year  = as.integer(year(date)),          # use parsed year (more reliable)
    age   = suppressWarnings(as.integer(str_extract(age_raw, "\\d+"))),
    closed = case_when(
      str_detect(tolower(closed_raw), "closed") ~ "Closed",
      TRUE ~ "Open / Unknown"
    ),
    has_cctv = case_when(
      str_detect(tolower(cctv_raw), "\\d+") ~ "Camera Present",
      str_detect(tolower(cctv_raw), "none")  ~ "No Camera",
      TRUE ~ "Unknown"
    ),
    method = case_when(
      str_detect(tolower(notes_raw), "stab")     ~ "Stabbing",
      str_detect(tolower(notes_raw), "shoot|shot|shooting|gunshot") ~ "Shooting",
      str_detect(tolower(notes_raw), "assault")  ~ "Assault",
      TRUE ~ "Other / Unknown"
    )
  )

cat("\n=== Data Summary ===\n")
cat("Total records scraped (2024 + 2025):", nrow(all_clean), "\n")
cat("  2024:", sum(all_clean$year == 2024, na.rm = TRUE), "\n")
cat("  2025:", sum(all_clean$year == 2025, na.rm = TRUE), "\n\n")

# ── histogram: homicides by month, 2024 vs 2025 ───────────────────────────────

monthly <- all_clean %>%
  filter(!is.na(month_num)) %>%
  count(year, month_num, month) %>%
  mutate(year = factor(year))

# Save as PNG
png("homicides_by_month.png", width = 900, height = 520, res = 110)
p <- ggplot(monthly, aes(x = month, y = n, fill = year)) +
  geom_bar(stat = "identity", position = "dodge", colour = "white", width = 0.7) +
  scale_fill_manual(values = c("2024" = "#1f77b4", "2025" = "#d62728"),
                    name = "Year") +
  labs(
    title    = "Baltimore City Homicides by Month: 2024 vs 2025",
    subtitle = "Source: chamspage.blogspot.com | scraped with R/rvest",
    x        = "Month",
    y        = "Number of Homicides",
    caption  = "Note: rows with non-standard dates or XXX/removed entries excluded."
  ) +
  theme_bw(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold"),
    legend.position = "top",
    axis.text.x  = element_text(angle = 0, hjust = 0.5)
  )
print(p)
dev.off()
message("Histogram saved to homicides_by_month.png")

# ── tabular output to stdout ──────────────────────────────────────────────────

# Build a wide table: rows = months, columns = 2024 count, 2025 count, diff
table_wide <- monthly %>%
  tidyr::pivot_wider(
    id_cols     = c(month_num, month),
    names_from  = year,
    values_from = n,
    values_fill = 0
  ) %>%
  arrange(month_num)

# Ensure both year columns exist even if one year has no data
for (yr in c("2024", "2025")) {
  if (!yr %in% names(table_wide)) table_wide[[yr]] <- 0L
}

table_wide <- table_wide %>%
  mutate(Change = .data[["2025"]] - .data[["2024"]]) %>%
  select(Month = month, `2024`, `2025`, Change)

totals <- tibble(
  Month  = "TOTAL",
  `2024` = sum(table_wide$`2024`),
  `2025` = sum(table_wide$`2025`),
  Change = sum(table_wide$Change)
)

final_table <- bind_rows(table_wide, totals)

cat("\n=== Baltimore City Homicides by Month: 2024 vs 2025 ===\n")
cat(sprintf("%-8s %6s %6s %8s\n", "Month", "2024", "2025", "Change"))
cat(strrep("-", 34), "\n")
for (i in seq_len(nrow(final_table))) {
  row <- final_table[i, ]
  if (row$Month == "TOTAL") cat(strrep("-", 34), "\n")
  cat(sprintf("%-8s %6d %6d %+8d\n",
              row$Month, row$`2024`, row$`2025`, row$Change))
}

# ── method breakdown (bonus) ──────────────────────────────────────────────────
method_tbl <- all_clean %>%
  filter(!is.na(method)) %>%
  count(year, method) %>%
  tidyr::pivot_wider(names_from = year, values_from = n, values_fill = 0) %>%
  arrange(desc(rowSums(across(where(is.integer)))))

for (yr in c("2024", "2025")) {
  if (!as.character(yr) %in% names(method_tbl)) method_tbl[[as.character(yr)]] <- 0L
}

cat("\n=== Homicide Method Breakdown ===\n")
cat(sprintf("%-20s %6s %6s\n", "Method", "2024", "2025"))
cat(strrep("-", 34), "\n")
for (i in seq_len(nrow(method_tbl))) {
  row <- method_tbl[i, ]
  cat(sprintf("%-20s %6d %6d\n",
              row$method,
              as.integer(row[["2024"]]),
              as.integer(row[["2025"]])))
}

# ── age distribution (bonus) ─────────────────────────────────────────────────
age_valid <- all_clean %>% filter(!is.na(age), age >= 1, age <= 100)
cat("\n=== Victim Age Statistics (2024 + 2025 combined) ===\n")
cat(sprintf("  Min age   : %d\n", min(age_valid$age)))
cat(sprintf("  Max age   : %d\n", max(age_valid$age)))
cat(sprintf("  Mean age  : %.1f\n", mean(age_valid$age)))
cat(sprintf("  Median age: %.1f\n", median(age_valid$age)))

cat("\nDone.\n")
