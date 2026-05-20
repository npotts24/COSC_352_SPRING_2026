

suppressPackageStartupMessages({
  library(xml2)
  library(rvest)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(tidyr)
  library(ggplot2)
  library(httr)
})



fetch_html <- function(url) {

  resp <- tryCatch(
    httr::GET(
      url,
      httr::user_agent("COSC-Assignment-R-Scraper/1.0 (student project)"),
      httr::timeout(30)
    ),
    error = function(e) e
  )

  if (inherits(resp, "error")) {
    stop("Network error while fetching: ", url, "\n", resp$message)
  }
  if (httr::status_code(resp) >= 400) {
    stop("HTTP error ", httr::status_code(resp), " while fetching: ", url)
  }

  html_txt <- httr::content(resp, as = "text", encoding = "UTF-8")
  xml2::read_html(html_txt)
}

pick_main_table <- function(tables) {
  if (length(tables) == 0) return(NULL)

  scores <- vapply(tables, function(df) {
    nrow(df) * ncol(df)
  }, numeric(1))

  tables[[which.max(scores)]]
}

standardize_colnames <- function(df) {
  names(df) <- str_squish(names(df))
  df
}

parse_camera_count <- function(x) {
 
  x <- str_to_lower(str_squish(as.character(x)))
  ifelse(
    str_detect(x, "none|^$|na"),
    0L,
    suppressWarnings(as.integer(str_extract(x, "\\d+")))
  ) %>% replace_na(0L)
}

parse_closed_flag <- function(x) {
  x <- str_to_lower(str_squish(as.character(x)))
  
  str_detect(x, "closed")
}

scrape_year <- function(url, year) {
  page <- fetch_html(url)

  tables <- page %>% html_elements("table") %>% html_table(fill = TRUE)
  main <- pick_main_table(tables)
  if (is.null(main)) stop("No HTML table found at: ", url)

  main <- standardize_colnames(main)

 
  want <- c("No.", "Date Died", "Name", "Age", "Address Block Found", "Notes",
            "Victim Has No Violent Criminal History*", "Surveillance Camera At Intersection?**", "Case Closed?")
  for (w in want) {
    if (!(w %in% names(main))) main[[w]] <- NA_character_
  }

  df <- main %>%
    transmute(
      year = year,
      raw_no = as.character(`No.`),
      date_raw = as.character(`Date Died`),
      name = as.character(`Name`),
      age_raw = as.character(`Age`),
      address = as.character(`Address Block Found`),
      notes = as.character(`Notes`),
      camera_raw = as.character(`Surveillance Camera At Intersection?**`),
      closed_raw = as.character(`Case Closed?`)
    ) %>%
    mutate(
      
      date_raw = str_squish(date_raw),
      name = str_squish(name),
      notes = str_squish(notes),
      address = str_squish(address),

      # Parse dates:
      # Most rows look like "01/09/25". Some "XXX" rows may have "11/2014" etc.
      date_died = suppressWarnings(lubridate::mdy(date_raw)),
      age = suppressWarnings(as.integer(str_extract(age_raw, "\\d+"))),
      camera_count = parse_camera_count(camera_raw),
      case_closed = parse_closed_flag(closed_raw)
    ) %>%
    # Keep entries that parse as a date in the target year
    filter(!is.na(date_died), lubridate::year(date_died) == year) %>%
    # Drop obviously empty names if any
    filter(!is.na(name), name != "") %>%
    mutate(
      month = lubridate::month(date_died, label = TRUE, abbr = TRUE)
    )

  df
}


urls <- list(
  `2025` = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  `2024` = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html"
)

message("Scraping homicide lists...")
data_all <- bind_rows(
  scrape_year(urls[["2025"]], 2025),
  scrape_year(urls[["2024"]], 2024)
)


hist_tbl <- data_all %>%
  count(year, month, name = "homicides") %>%
  group_by(year) %>%

  complete(month = factor(month.abb, levels = month.abb), fill = list(homicides = 0)) %>%
  ungroup() %>%
  mutate(month = factor(month, levels = month.abb)) %>%
  arrange(year, month)


cat("\n=== Tabular Histogram: Baltimore City Homicides by Month (Cham's Blog) ===\n\n")
# Print in a nice aligned format
print(hist_tbl %>% arrange(year, month), n = 1000)


p <- ggplot(hist_tbl, aes(x = month, y = homicides, group = factor(year), fill = factor(year))) +
  geom_col(position = "dodge") +
  labs(
    title = "Baltimore City Homicides by Month (2024 vs 2025) — Cham's Blog",
    x = "Month",
    y = "Number of homicides",
    fill = "Year"
  ) +
  theme_minimal(base_size = 12)

ggsave("histogram.png", plot = p, width = 11, height = 6, dpi = 150)
cat("\nSaved plot to: histogram.png\n")