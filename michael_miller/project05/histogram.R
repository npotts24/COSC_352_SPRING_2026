# histogram.R
# Baltimore City Homicide Data Analysis
# Scrapes 2023, 2024, and 2025 data from chamspage.blogspot.com
# Statistic: Homicides by Month (multi-year comparison)
# Also: Age distribution (2025) and Method breakdown

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
})

# ---- Helper: scrape one year into a data frame ----
scrape_year <- function(url, year_label) {
  message(paste("Scraping:", url))
  tryCatch({
    page     <- read_html(url)
    tables   <- html_elements(page, "table")
    if (length(tables) == 0) {
      message("No tables found for ", year_label)
      return(NULL)
    }
    tbl_list <- lapply(tables, function(t) html_table(t, fill = TRUE))
    sizes    <- sapply(tbl_list, nrow)
    df       <- tbl_list[[which.max(sizes)]]
    names(df) <- tolower(trimws(names(df)))

    date_col   <- names(df)[grepl("date",        names(df))][1]
    age_col    <- names(df)[grepl("^age$",       names(df))][1]
    note_col   <- names(df)[grepl("note|method", names(df))][1]
    closed_col <- names(df)[grepl("clos|case",   names(df))][1]

    out <- data.frame(year = year_label, stringsAsFactors = FALSE)

    if (!is.na(date_col)) {
      parsed         <- suppressWarnings(mdy(as.character(df[[date_col]])))
      out$date       <- parsed
      out$month      <- month(parsed)
      out$month_name <- month(parsed, label = TRUE, abbr = FALSE)
    } else {
      out$date <- NA; out$month <- NA; out$month_name <- NA
    }

    out$age <- if (!is.na(age_col)) {
      suppressWarnings(as.integer(as.character(df[[age_col]])))
    } else NA

    if (!is.na(note_col)) {
      notes      <- tolower(as.character(df[[note_col]]))
      out$method <- case_when(
        str_detect(notes, "shoot|shot|gunshot") ~ "Shooting",
        str_detect(notes, "stab")               ~ "Stabbing",
        str_detect(notes, "beat|assault")       ~ "Assault",
        TRUE                                    ~ "Other/Unknown"
      )
    } else {
      out$method <- "Unknown"
    }

    out$closed <- if (!is.na(closed_col)) {
      str_detect(tolower(as.character(df[[closed_col]])), "clos|yes")
    } else NA

    out <- out[!is.na(out$month), ]
    out
  }, error = function(e) {
    message("Error scraping ", year_label, ": ", e$message)
    NULL
  })
}

# ---- Scrape 2023, 2024, 2025 ----
year_urls <- list(
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  "2023" = "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html"
)

all_data <- do.call(rbind, lapply(names(year_urls), function(yr) {
  scrape_year(year_urls[[yr]], yr)
}))

if (is.null(all_data) || nrow(all_data) == 0) stop("No data scraped.")
message(paste("Total records:", nrow(all_data)))

# ---- Summaries ----
monthly <- all_data |>
  filter(!is.na(month)) |>
  group_by(month, month_name) |>
  summarise(count = n(), .groups = "drop") |>
  arrange(month)

yoy <- all_data |>
  filter(!is.na(month)) |>
  group_by(year, month, month_name) |>
  summarise(count = n(), .groups = "drop") |>
  arrange(year, month)

method_tbl <- all_data |>
  filter(!is.na(method)) |>
  count(method, name = "count") |>
  arrange(desc(count))

age_data <- all_data |>
  filter(year == "2025", !is.na(age), age > 0, age < 110)

# ---- Print: Homicides by Month ----
cat("\n", strrep("=", 62), "\n", sep = "")
cat("  BALTIMORE CITY HOMICIDES BY MONTH (2023-2025 Combined)\n")
cat(strrep("=", 62), "\n", sep = "")
cat(sprintf("%-15s %6s   %s\n", "Month", "Count", "Bar (each # = 2 homicides)"))
cat(strrep("-", 62), "\n", sep = "")
for (i in seq_len(nrow(monthly))) {
  bar <- strrep("#", monthly$count[i] %/% 2)
  cat(sprintf("%-15s %6d   %s\n",
      as.character(monthly$month_name[i]), monthly$count[i], bar))
}
cat(strrep("-", 62), "\n", sep = "")
cat(sprintf("%-15s %6d\n", "TOTAL", sum(monthly$count)))

# ---- Print: Year-over-Year ----
yrs <- sort(unique(yoy$year))
cat("\n", strrep("=", 62), "\n", sep = "")
cat("  YEAR-OVER-YEAR MONTHLY BREAKDOWN\n")
cat(strrep("=", 62), "\n", sep = "")
hdr <- sprintf("%-12s", "Month")
for (y in yrs) hdr <- paste0(hdr, sprintf("%8s", y))
cat(hdr, "\n")
cat(strrep("-", 62), "\n", sep = "")
for (m in 1:12) {
  mn  <- as.character(month(m, label = TRUE, abbr = FALSE))
  row <- sprintf("%-12s", mn)
  for (y in yrs) {
    v <- yoy$count[yoy$month == m & yoy$year == y]
    row <- paste0(row, sprintf("%8s", ifelse(length(v) == 0, "-", v)))
  }
  cat(row, "\n")
}

# ---- Print: Method breakdown ----
cat("\n", strrep("=", 62), "\n", sep = "")
cat("  HOMICIDE METHOD BREAKDOWN\n")
cat(strrep("=", 62), "\n", sep = "")
cat(sprintf("%-20s %6s   %s\n", "Method", "Count", "Bar (each # = 5)"))
cat(strrep("-", 50), "\n", sep = "")
for (i in seq_len(nrow(method_tbl))) {
  bar <- strrep("#", method_tbl$count[i] %/% 5)
  cat(sprintf("%-20s %6d   %s\n", method_tbl$method[i], method_tbl$count[i], bar))
}

# ---- Print: Age distribution 2025 ----
if (nrow(age_data) > 0) {
  cat("\n", strrep("=", 62), "\n", sep = "")
  cat("  VICTIM AGE DISTRIBUTION (2025)\n")
  cat(strrep("=", 62), "\n", sep = "")
  brks <- c(0, 10, 20, 30, 40, 50, 60, 70, 80, 110)
  lbls <- c("0-9", "10-19", "20-29", "30-39", "40-49", "50-59", "60-69", "70-79", "80+")
  bins <- cut(age_data$age, breaks = brks, labels = lbls, right = FALSE)
  at   <- as.data.frame(table(bins))
  cat(sprintf("%-10s %6s   %s\n", "Age Group", "Count", "Bar"))
  cat(strrep("-", 50), "\n", sep = "")
  for (i in seq_len(nrow(at))) {
    bar <- strrep("#", at$Freq[i])
    cat(sprintf("%-10s %6d   %s\n", as.character(at$bins[i]), at$Freq[i], bar))
  }
}

message("Done.")