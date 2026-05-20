#!/usr/bin/env Rscript
# Baltimore City Homicide Histogram
# Confirmed column order from page: No. | Date | Name | Age | Address | Notes | Camera | Closed

suppressPackageStartupMessages({
  library(rvest)
  library(dplyr)
  library(stringr)
  library(ggplot2)
  library(lubridate)
})

# ─────────────────────────────────────────────────────────────────
# 1. URLs — only 2025 is confirmed; prior years use same URL pattern
#    and are skipped gracefully if they 404 or fail to load.
# ─────────────────────────────────────────────────────────────────
urls <- list(
  `2025` = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  `2024` = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  `2023` = "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html",
  `2022` = "https://chamspage.blogspot.com/2022/01/2022-baltimore-city-homicide-list.html",
  `2021` = "https://chamspage.blogspot.com/2021/01/2021-baltimore-city-homicide-list.html"
)

# ─────────────────────────────────────────────────────────────────
# 2. Scrape one year's page
#
# Actual column order (verified from screenshot + HTML fetch):
#   No. | Date | Name | Age | Address | Notes | Camera | Closed
#
# Quirks:
#   - "XXX" in No. = removed/justified case → skip
#   - Camera cell: "None", "1 camera", "2 cameras", or blank
#   - Closed cell: "Closed" or blank
#   - Some rows have nested sub-tables in Notes (images, updates)
#     → html_text() collapses these cleanly
# ─────────────────────────────────────────────────────────────────
scrape_year <- function(url, year) {
  message(sprintf("  Scraping %s ...", year))

  page <- tryCatch(
    read_html(url),
    error = function(e) { message("    FAILED: ", e$message); return(NULL) }
  )
  if (is.null(page)) return(NULL)

  rows <- html_elements(page, "tr")
  if (length(rows) == 0) { message("    No rows found."); return(NULL) }

  records <- lapply(rows, function(row) {
    cells <- html_elements(row, "td")
    if (length(cells) < 4) return(NULL)   # skip header rows (use <th>) and too-short rows

    txt <- str_squish(html_text(cells, trim = TRUE))

    # Positional extraction — confirmed column order
    no_val    <- txt[1]
    date_val  <- if (length(txt) >= 2) txt[2] else NA_character_
    name_val  <- if (length(txt) >= 3) txt[3] else NA_character_
    age_val   <- if (length(txt) >= 4) txt[4] else NA_character_
    addr_val  <- if (length(txt) >= 5) txt[5] else NA_character_
    notes_val <- if (length(txt) >= 6) txt[6] else NA_character_

    # Camera and Closed may appear in cells 7+ OR be embedded inside notes
    rest      <- paste(txt[7:min(length(txt), 20)], collapse = " ")
    all_txt   <- paste(notes_val, rest, collapse = " ")

    # Count cameras mentioned
    cam_count <- case_when(
      str_detect(all_txt, regex("(\\d+)\\s*camera", ignore_case = TRUE)) ~
        suppressWarnings(as.integer(str_extract(all_txt, "\\d+(?=\\s*camera)"))),
      str_detect(all_txt, regex("\\bNone\\b", ignore_case = TRUE)) ~ 0L,
      TRUE ~ NA_integer_
    )

    closed_val <- str_detect(all_txt, regex("\\bClosed\\b", ignore_case = TRUE))

    list(
      no           = no_val,
      date         = date_val,
      name         = name_val,
      age          = age_val,
      address      = addr_val,
      notes        = notes_val,
      cameras      = cam_count,
      closed       = closed_val,
      year_scraped = as.integer(year)
    )
  })

  records <- Filter(Negate(is.null), records)
  if (length(records) == 0) return(NULL)

  bind_rows(lapply(records, as.data.frame, stringsAsFactors = FALSE))
}

# ─────────────────────────────────────────────────────────────────
# 3. Scrape all years
# ─────────────────────────────────────────────────────────────────
message("Fetching Baltimore City homicide data…")
raw_list <- mapply(scrape_year, urls, names(urls), SIMPLIFY = FALSE)
raw_list <- Filter(Negate(is.null), raw_list)

if (length(raw_list) == 0) stop("No data fetched. Check network access.")

all_data <- bind_rows(raw_list)

# ─────────────────────────────────────────────────────────────────
# 4. Clean
# ─────────────────────────────────────────────────────────────────
clean <- all_data %>%
  filter(
    !is.na(no),
    # Drop header rows
    !str_detect(trimws(no), regex("^(no\\.?|#|num)", ignore_case = TRUE)),
    # Drop XXX rows (removed / justified homicides)
    !str_detect(trimws(no), regex("^xxx", ignore_case = TRUE))
  ) %>%
  mutate(
    age_num = suppressWarnings(as.integer(str_extract(age, "\\d+"))),

    # Primary date format on this blog: MM/DD/YY
    date_clean = parse_date_time(date,
                   orders = c("m/d/y", "m/d/Y", "B d, Y", "b d Y"),
                   quiet  = TRUE),

    month_num  = month(date_clean),
    month_name = month(date_clean, label = TRUE, abbr = TRUE),
    year_event = coalesce(year(date_clean), as.integer(year_scraped)),

    # Method inferred from Notes text
    method = case_when(
      str_detect(tolower(notes), "shoot|gun|shot")           ~ "Shooting",
      str_detect(tolower(notes), "stab|cut|slash")           ~ "Stabbing",
      str_detect(tolower(notes), "beat|blunt|assault|punch") ~ "Blunt/Assault",
      str_detect(tolower(notes), "strangle|asphyx|suffoc")   ~ "Asphyxiation",
      str_detect(tolower(notes), "vehicl|car crash|struck")  ~ "Vehicle",
      !is.na(notes) & nchar(trimws(notes)) > 0              ~ "Other/Unknown",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(age_num), age_num >= 1, age_num <= 110)

n_total   <- nrow(clean)
yrs_found <- paste(sort(unique(clean$year_event)), collapse = ", ")
message(sprintf("  %d valid victim records | year(s): %s", n_total, yrs_found))
if (n_total == 0) stop("No valid records after cleaning.")

# ─────────────────────────────────────────────────────────────────
# 5. Build age-bin counts
# ─────────────────────────────────────────────────────────────────
age_breaks  <- seq(0, 105, by = 5)
bin_labels  <- paste0(head(age_breaks, -1), "-", tail(age_breaks, -1) - 1)

hist_data <- clean %>%
  mutate(age_bin = cut(age_num, breaks = age_breaks,
                       right = FALSE, labels = bin_labels)) %>%
  filter(!is.na(age_bin)) %>%
  count(age_bin, name = "count") %>%
  right_join(data.frame(age_bin = factor(bin_labels, levels = bin_labels)),
             by = "age_bin") %>%
  mutate(count = coalesce(count, 0L))

# ─────────────────────────────────────────────────────────────────
# 6. Print tabular histogram to stdout
# ─────────────────────────────────────────────────────────────────
max_count <- max(hist_data$count, 1L)
bar_width  <- 40

cat("\n")
cat(strrep("=", 68), "\n")
cat("  BALTIMORE CITY HOMICIDE VICTIMS — AGE DISTRIBUTION\n")
cat(sprintf("  Years: %-20s  Total victims: %d\n", yrs_found, n_total))
cat(strrep("=", 68), "\n")
cat(sprintf("  %-9s  %6s  %6s  %s\n", "Age", "Count", "Pct", "Bar"))
cat(sprintf("  %s\n", strrep("-", 64)))

for (i in seq_len(nrow(hist_data))) {
  r   <- hist_data[i, ]
  pct <- 100 * r$count / n_total
  bar <- strrep("\u2588", round(bar_width * r$count / max_count))
  cat(sprintf("  %-9s  %6d  %5.1f%%  %s\n",
              as.character(r$age_bin), r$count, pct, bar))
}

cat(sprintf("  %s\n", strrep("-", 64)))
cat(sprintf("  %-9s  %6d  100.0%%\n\n", "TOTAL", n_total))

# Method breakdown
method_tbl <- clean %>%
  filter(!is.na(method)) %>%
  count(method, sort = TRUE) %>%
  mutate(pct = 100 * n / sum(n))

if (nrow(method_tbl) > 0) {
  cat("  METHOD OF KILLING\n")
  cat(sprintf("  %s\n", strrep("-", 42)))
  for (i in seq_len(nrow(method_tbl))) {
    cat(sprintf("  %-22s  %5d  (%5.1f%%)\n",
                method_tbl$method[i], method_tbl$n[i], method_tbl$pct[i]))
  }
  cat("\n")
}

# Camera proximity
cam_tbl <- clean %>%
  filter(!is.na(cameras)) %>%
  mutate(cam_label = case_when(
    cameras == 0 ~ "No camera nearby",
    cameras == 1 ~ "1 camera nearby",
    cameras >= 2 ~ "2+ cameras nearby"
  )) %>%
  count(cam_label, sort = TRUE) %>%
  mutate(pct = 100 * n / sum(n))

if (nrow(cam_tbl) > 0) {
  cat("  SURVEILLANCE CAMERA PROXIMITY\n")
  cat(sprintf("  %s\n", strrep("-", 42)))
  for (i in seq_len(nrow(cam_tbl))) {
    cat(sprintf("  %-22s  %5d  (%5.1f%%)\n",
                cam_tbl$cam_label[i], cam_tbl$n[i], cam_tbl$pct[i]))
  }
  cat("\n")
}

# Case closure
closed_n <- sum(clean$closed, na.rm = TRUE)
cat("  CASE CLOSURE STATUS\n")
cat(sprintf("  %s\n", strrep("-", 42)))
cat(sprintf("  %-22s  %5d  (%5.1f%%)\n", "Closed", closed_n,
            100 * closed_n / n_total))
cat(sprintf("  %-22s  %5d  (%5.1f%%)\n", "Open / Unknown",
            n_total - closed_n, 100 * (n_total - closed_n) / n_total))
cat("\n")

# Annual totals
year_tbl <- clean %>% count(year_event, sort = FALSE)
cat("  ANNUAL TOTALS\n")
cat(sprintf("  %s\n", strrep("-", 30)))
for (i in seq_len(nrow(year_tbl))) {
  cat(sprintf("  %d  ->  %d victims\n", year_tbl$year_event[i], year_tbl$n[i]))
}
cat("\n")

# ─────────────────────────────────────────────────────────────────
# 7. ggplot2 histogram → /output/histogram.png
# ─────────────────────────────────────────────────────────────────
dir.create("/output", showWarnings = FALSE)

year_colors <- c(`2021`="#c0392b", `2022`="#e67e22",
                 `2023`="#f39c12", `2024`="#27ae60", `2025`="#2980b9")

p <- ggplot(clean, aes(x = age_num, fill = factor(year_event))) +
  geom_histogram(binwidth = 5, colour = "white", linewidth = 0.25,
                 boundary = 0, position = "stack") +
  scale_x_continuous(breaks = seq(0, 100, 10), limits = c(0, 101),
                     expand = expansion(mult = c(0, 0.01))) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  scale_fill_manual(values = year_colors, name = "Year") +
  labs(
    title    = "Baltimore City Homicide Victims by Age",
    subtitle = sprintf("n = %d victims with recorded ages  |  Years: %s",
                       n_total, yrs_found),
    x        = "Victim Age (years)",
    y        = "Number of Victims",
    caption  = "Source: chamspage.blogspot.com  |  Scraped with rvest in R"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title         = element_text(face = "bold", size = 15),
    plot.subtitle      = element_text(colour = "grey40", size = 10),
    plot.caption       = element_text(colour = "grey55", size = 8),
    legend.position    = "right",
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank()
  )

ggsave("/output/histogram.png", plot = p, width = 10, height = 6, dpi = 150)
message("  Saved: /output/histogram.png")
