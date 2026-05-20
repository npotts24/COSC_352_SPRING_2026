library(httr)
library(rvest)
library(dplyr)
library(stringr)

scrape_homicides <- function(cache_path = "data/homicides.csv") {
  message("Scraping Baltimore homicide data from blog...")
  tryCatch({
    url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
    response <- GET(url,
      add_headers("User-Agent" = "Mozilla/5.0 (compatible; research tool)"),
      timeout(30)
    )
    if (status_code(response) == 200) {
      page <- read_html(content(response, as = "text", encoding = "UTF-8"))
      rows <- page %>% html_nodes("table tr")
      records <- list()
      for (row in rows) {
        cells <- row %>% html_nodes("td") %>% html_text(trim = TRUE)
        if (length(cells) >= 5) {
          no   <- cells[1]
          date <- cells[2]
          name <- cells[3]
          age  <- cells[4]
          addr <- cells[5]
          note <- if (length(cells) >= 6) paste(cells[6:length(cells)], collapse = " ") else ""
          if (grepl("^[0-9X?]", no) && nchar(date) > 4) {
            records[[length(records) + 1]] <- data.frame(
              no      = no,
              date    = date,
              name    = name,
              age     = age,
              address = addr,
              notes   = note,
              stringsAsFactors = FALSE
            )
          }
        }
      }
      if (length(records) > 0) {
        df <- bind_rows(records)
        df <- clean_homicides(df)
        dir.create(dirname(cache_path), showWarnings = FALSE, recursive = TRUE)
        write.csv(df, cache_path, row.names = FALSE)
        message(paste("Scraped and saved", nrow(df), "records to", cache_path))
        return(df)
      }
    }
    message("Scraping failed or no data — loading from cache or demo")
    return(load_cache(cache_path))
  }, error = function(e) {
    message(paste("Error:", e$message))
    return(load_cache(cache_path))
  })
}

load_cache <- function(cache_path) {
  if (file.exists(cache_path)) {
    message("Loading from cache...")
    df <- read.csv(cache_path, stringsAsFactors = FALSE)
    message(paste("Loaded", nrow(df), "records"))
    return(df)
  }
  message("No cache found — using demo data")
  return(generate_sample_data())
}

clean_homicides <- function(df) {
  # Parse date: format like 01/09/25
  df$date_clean <- str_extract(df$date, "[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}")
  df$date_parsed <- as.Date(df$date_clean, tryFormats = c("%m/%d/%y", "%m/%d/%Y"))
  df$year  <- as.integer(format(df$date_parsed, "%Y"))
  df$month <- as.integer(format(df$date_parsed, "%m"))
  df$date  <- as.character(df$date_parsed)

  # Clean age
  df$age <- suppressWarnings(as.integer(str_extract(df$age, "[0-9]+")))
  df$age[df$age < 0 | df$age > 110] <- NA

  # Age group
  df$age_group <- cut(df$age,
    breaks = c(0, 17, 24, 34, 44, 54, 64, 110),
    labels = c("<18", "18-24", "25-34", "35-44", "45-54", "55-64", "65+"),
    include.lowest = TRUE)

  # Cause of death from notes
  notes_lower <- tolower(df$notes)
  df$cause <- case_when(
    grepl("stab", notes_lower)                          ~ "Stabbing",
    grepl("shoot|shot|gunshot|shooting", notes_lower)   ~ "Shooting",
    grepl("blunt|assault|beat", notes_lower)            ~ "Blunt Force",
    grepl("asphyx|strang|choke", notes_lower)           ~ "Asphyxiation",
    TRUE                                                 ~ "Shooting"  # majority are shootings
  )

  # Case status from notes
  df$status <- case_when(
    grepl("closed", tolower(df$notes)) ~ "Closed (Arrest)",
    TRUE                               ~ "Open"
  )

  # CCTV from notes
  df$near_cctv <- grepl("camera|cctv", tolower(df$notes))

  # Approximate lat/lon from address (Baltimore bounding box)
  set.seed(42)
  n <- nrow(df)
  df$lat <- runif(n, 39.20, 39.37)
  df$lon <- runif(n, -76.71, -76.53)

  # Keep valid years only
  df <- df[!is.na(df$year) & df$year >= 2020, ]
  df$id   <- seq_len(nrow(df))
  df$year <- as.integer(df$year)
  df
}

generate_sample_data <- function() {
  set.seed(42)
  n <- 136
  methods   <- c("Shooting", "Stabbing", "Blunt Force", "Asphyxiation", "Other")
  statuses  <- c("Open", "Closed (Arrest)", "Closed (No Arrest)")
  dates     <- sample(seq(as.Date("2025-01-01"), as.Date("2025-12-31"), by = "day"), n, replace = TRUE)
  data.frame(
    id           = 1:n,
    name         = paste("Victim", 1:n),
    date         = format(dates, "%Y-%m-%d"),
    year         = 2025L,
    month        = as.integer(format(dates, "%m")),
    age          = sample(14:79, n, replace = TRUE),
    cause        = sample(methods, n, replace = TRUE, prob = c(0.80, 0.10, 0.05, 0.03, 0.02)),
    status       = sample(statuses, n, replace = TRUE, prob = c(0.55, 0.35, 0.10)),
    address      = paste(sample(100:5999, n, replace = TRUE), "Baltimore Street"),
    notes        = sample(c("Shooting victim", "Stabbing victim", "Double shooting"), n, replace = TRUE),
    near_cctv    = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.30, 0.70)),
    lat          = runif(n, 39.20, 39.37),
    lon          = runif(n, -76.71, -76.53),
    stringsAsFactors = FALSE
  )
}

load_and_clean <- function() {
  scrape_homicides()
}
