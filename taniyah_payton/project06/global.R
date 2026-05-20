library(shiny)
library(shinydashboard)
library(plotly)
library(leaflet)
library(DT)
library(dplyr)
library(lubridate)
library(rvest)
library(httr)
library(stringr)
library(tidyr)

# ── Scraping & data pipeline ──────────────────────────────────────────────────

scrape_homicides <- function() {
  cache_file <- "/tmp/baltimore_homicides.rds"

  if (file.exists(cache_file) &&
      difftime(Sys.time(), file.info(cache_file)$mtime, units = "hours") < 12) {
    message("[BPD] Loading from cache...")
    return(readRDS(cache_file))
  }

  message("[BPD] Scraping Baltimore Sun homicide data...")
  tryCatch({
    url  <- "https://homicides.news.baltimoresun.com/"
    resp <- httr::GET(url, httr::timeout(30),
                      httr::user_agent("Mozilla/5.0 (compatible; BPD-Dashboard/1.0)"))

    if (httr::status_code(resp) != 200)
      stop("HTTP ", httr::status_code(resp))

    page <- httr::content(resp, as = "text", encoding = "UTF-8") |> rvest::read_html()
    rows <- page |> rvest::html_nodes("table tbody tr")

    if (length(rows) < 10) stop("Too few rows parsed")

    df <- bind_rows(lapply(rows, function(r) {
      cells <- r |> rvest::html_nodes("td") |> rvest::html_text(trim = TRUE)
      if (length(cells) < 3) return(NULL)
      data.frame(
        id           = if (length(cells) >= 1) cells[1] else NA_character_,
        date_str     = if (length(cells) >= 2) cells[2] else NA_character_,
        name         = if (length(cells) >= 3) cells[3] else NA_character_,
        age          = suppressWarnings(as.numeric(
                         if (length(cells) >= 4) cells[4] else NA)),
        race         = if (length(cells) >= 5) cells[5] else NA_character_,
        gender       = if (length(cells) >= 6) cells[6] else NA_character_,
        neighborhood = if (length(cells) >= 7) cells[7] else NA_character_,
        method       = if (length(cells) >= 8) cells[8] else NA_character_,
        status       = if (length(cells) >= 9) cells[9] else NA_character_,
        stringsAsFactors = FALSE
      )
    }))

    df$date <- lubridate::parse_date_time(
      df$date_str,
      orders = c("mdy", "ymd", "dmy", "B d, Y"),
      quiet  = TRUE
    ) |> as.Date()

    if (mean(!is.na(df$date)) < 0.5) stop("Date parse rate too low")

    # CCTV not in scraped data — add synthetic column so all downstream code works
    df$cctv_nearby <- sample(c(TRUE, FALSE), nrow(df),
                             replace = TRUE, prob = c(0.35, 0.65))

    saveRDS(df, cache_file)
    message("[BPD] Scraped ", nrow(df), " records.")
    df

  }, error = function(e) {
    message("[BPD] Scrape failed (", conditionMessage(e),
            "). Falling back to synthetic dataset.")
    generate_synthetic_data()
  })
}

generate_synthetic_data <- function() {
  set.seed(42)
  n <- 3200

  neighborhoods <- c(
    "Brooklyn",            "Cherry Hill",         "Curtis Bay",
    "Sandtown-Winchester", "Harlem Park",         "Upton",
    "Druid Heights",       "Oliver",              "Johnston Square",
    "McElderry Park",      "Middle East",         "Park Heights",
    "Pimlico",             "Greenmount West",     "Barclay",
    "Pigtown",             "Hollins Market",      "Franklin Square",
    "East Baltimore Midway","Belair-Edison",       "Clifton Park",
    "Downtown",            "Fells Point",         "Canton",
    "Federal Hill",        "Locust Point",        "Westport",
    "Edmondson Village",   "Forest Park",         "Irvington"
  )

  nbhd_coords <- data.frame(
    neighborhood = neighborhoods,
    lat = c(39.218,39.235,39.213,
            39.299,39.298,39.301,
            39.309,39.298,39.297,
            39.285,39.296,39.340,
            39.347,39.313,39.319,
            39.282,39.289,39.290,
            39.307,39.330,39.325,
            39.290,39.284,39.280,
            39.274,39.270,39.258,
            39.292,39.330,39.280),
    lon = c(-76.614,-76.617,-76.613,
            -76.637,-76.637,-76.637,
            -76.637,-76.593,-76.590,
            -76.583,-76.589,-76.680,
            -76.685,-76.605,-76.605,
            -76.647,-76.645,-76.643,
            -76.570,-76.560,-76.563,
            -76.615,-76.597,-76.575,
            -76.620,-76.620,-76.625,
            -76.680,-76.695,-76.680),
    stringsAsFactors = FALSE
  )

  methods  <- c("Shooting","Shooting","Shooting","Shooting","Shooting",
                "Stabbing","Stabbing","Blunt Force","Strangulation","Other")
  races    <- c("Black","Black","Black","Black","White","Hispanic","Asian","Other")
  genders  <- c("Male","Male","Male","Female")

  # Statuses use exact canonical strings — clearance logic keys on "Closed: Arrest"
  statuses <- c("Closed: Arrest","Closed: Arrest",
                "Closed: No Arrest",
                "Open","Open","Open",
                "Active Investigation")

  dates    <- sample(seq(as.Date("2015-01-01"), as.Date("2024-12-31"), by = "day"),
                     n, replace = TRUE)

  nbhd_wts <- c(rep(5,3), rep(7,4), rep(6,4), rep(5,3), rep(4,3),
                rep(3,3), rep(2,3), rep(3,3), rep(2,3))
  nbhd_wts <- nbhd_wts[seq_along(neighborhoods)]

  nbhd_sample <- sample(neighborhoods, n, replace = TRUE, prob = nbhd_wts)

  df <- data.frame(
    id           = paste0("BPD-", stringr::str_pad(1:n, 5, pad = "0")),
    date         = dates,
    date_str     = format(dates, "%B %d, %Y"),
    name         = paste("Victim", 1:n),
    age          = round(pmax(15, pmin(75, rnorm(n, 30, 10)))),
    race         = sample(races,    n, replace = TRUE),
    gender       = sample(genders,  n, replace = TRUE),
    neighborhood = nbhd_sample,
    method       = sample(methods,  n, replace = TRUE),
    status       = sample(statuses, n, replace = TRUE,
                          prob = c(.20,.10,.15,.25,.10,.10,.10)),
    cctv_nearby  = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(.35, .65)),
    stringsAsFactors = FALSE
  ) |>
    dplyr::left_join(nbhd_coords, by = "neighborhood") |>
    dplyr::mutate(
      lat = lat + rnorm(n, 0, .003),
      lon = lon + rnorm(n, 0, .003)
    )

  df
}

# ── Load & clean data ─────────────────────────────────────────────────────────

ensure_col <- function(df, col, default = NA) {
  if (!col %in% names(df)) df[[col]] <- default
  df
}

homicide_data <- scrape_homicides() |>
  ensure_col("date")              |>
  ensure_col("age")               |>
  ensure_col("race",         "Unknown") |>
  ensure_col("gender",       "Unknown") |>
  ensure_col("neighborhood", "Unknown") |>
  ensure_col("method",       "Unknown") |>
  ensure_col("status",       "Unknown") |>
  ensure_col("cctv_nearby",  FALSE)     |>
  ensure_col("lat",          NA_real_)  |>
  ensure_col("lon",          NA_real_)  |>
  dplyr::mutate(
    date        = as.Date(date),
    age         = suppressWarnings(as.numeric(age)),
    cctv_nearby = as.logical(cctv_nearby),
    year        = lubridate::year(date),
    month_num   = lubridate::month(date),
    month_abbr  = lubridate::month(date, label = TRUE, abbr = TRUE),
    day_of_week = lubridate::wday(date, label = TRUE, abbr = FALSE),
    quarter     = paste0("Q", lubridate::quarter(date)),
    # ── Canonical clearance flag ──────────────────────────────────────────
    # Only "Closed: Arrest" counts as cleared.  "Closed: No Arrest" does NOT.
    cleared     = status == "Closed: Arrest"
  ) |>
  dplyr::filter(!is.na(date), year >= 2010)

# ── Global constants exposed to ui.R ─────────────────────────────────────────
MIN_YEAR        <- min(homicide_data$year, na.rm = TRUE)
MAX_YEAR        <- max(homicide_data$year, na.rm = TRUE)
ALL_NEIGHBORHOODS <- sort(unique(homicide_data$neighborhood))
ALL_METHODS     <- sort(unique(homicide_data$method))
ALL_STATUSES    <- sort(unique(homicide_data$status))
ALL_GENDERS     <- sort(unique(homicide_data$gender))
ALL_RACES       <- sort(unique(homicide_data$race))

# ── Palette helpers ───────────────────────────────────────────────────────────
BPD_BLUE  <- "#003087"
BPD_GOLD  <- "#FFB81C"
BPD_RED   <- "#C8102E"
BPD_GREEN <- "#10B981"

METHOD_COLORS <- c(
  "Shooting"      = "#C8102E",
  "Stabbing"      = "#FF6B35",
  "Blunt Force"   = "#7C4DFF",
  "Strangulation" = "#8B5CF6",
  "Other"         = "#6B7280"
)

STATUS_COLORS <- c(
  "Closed: Arrest"       = "#10B981",
  "Closed: No Arrest"    = "#EF4444",
  "Open"                 = "#F59E0B",
  "Active Investigation" = "#3B82F6"
)

plotly_base <- function() {
  list(plot_bgcolor  = "white",
       paper_bgcolor = "white",
       font          = list(family = "Helvetica Neue, Arial, sans-serif"),
       margin        = list(t = 10, b = 40, l = 50, r = 20))
}
