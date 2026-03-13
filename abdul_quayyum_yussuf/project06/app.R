# ============================================================================
# Baltimore City Police Department — Homicide Analysis Dashboard
# Reuses Project 5 (Part 1) scraping/parsing pipeline from Cham's Page
# ============================================================================

library(shiny)
library(shinydashboard)
library(rvest)
library(stringr)
library(ggplot2)
library(plotly)
library(DT)

# ============================================================================
# DATA PIPELINE — reused from Project 5 (histogram.R)
# ============================================================================

BASE_URL <- "https://chamspage.blogspot.com"
URLS <- list(
  "2025" = paste0(BASE_URL, "/2025/01/2025-baltimore-city-homicide-list.html"),
  "2024" = paste0(BASE_URL, "/2024/01/2024-baltimore-city-homicide-list.html"),
  "2023" = paste0(BASE_URL, "/2023/01/2023-baltimore-city-homicide-list.html")
)

scrape_year <- function(url, year) {
  tryCatch({
    page <- read_html(url)
    tables <- page %>% html_table(fill = TRUE)
    if (length(tables) == 0) return(NULL)
    best <- NULL
    for (tbl in tables) {
      if (nrow(tbl) > 5 && ncol(tbl) > 3) {
        cn <- tolower(names(tbl))
        if (any(grepl("victim|name|age|date|method|address|camera|closed", cn))) {
          best <- tbl
          break
        }
      }
    }
    if (is.null(best)) {
      sizes <- sapply(tables, function(x) nrow(x) * ncol(x))
      best <- tables[[which.max(sizes)]]
    }
    best$scrape_year <- as.integer(year)
    best
  }, error = function(e) NULL)
}

find_col <- function(df, patterns) {
  cn <- tolower(names(df))
  for (p in patterns) {
    idx <- grep(p, cn, ignore.case = TRUE)
    if (length(idx)) return(idx[1])
  }
  NA_integer_
}

extract_age <- function(x) {
  x <- as.character(x)
  if (is.na(x) || trimws(x) == "") return(NA_real_)
  x <- str_trim(x)
  x <- str_remove(x, "\\s+years?\\s*old.*$")
  m <- str_extract(x, "\\d+")
  if (is.na(m)) return(NA_real_)
  a <- as.numeric(m)
  if (a < 1 || a > 120) return(NA_real_)
  a
}

parse_date <- function(x, year) {
  x <- trimws(as.character(x))
  if (is.na(x) || x == "") return(as.Date(NA))
  parts <- strsplit(x, "[/-]")[[1]]
  if (length(parts) < 2) return(as.Date(NA))
  mo <- suppressWarnings(as.integer(trimws(parts[1])))
  dy <- suppressWarnings(as.integer(trimws(parts[2])))
  yr <- as.integer(year)
  if (length(parts) >= 3) {
    y2 <- suppressWarnings(as.integer(trimws(parts[3])))
    if (!is.na(y2)) yr <- ifelse(y2 < 100, y2 + 2000, y2)
  }
  if (is.na(mo) || is.na(dy) || is.na(yr) ||
      mo < 1 || mo > 12 || dy < 1 || dy > 31) return(as.Date(NA))
  suppressWarnings(as.Date(sprintf("%04d-%02d-%02d", yr, mo, dy)))
}

clean_table <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(NULL)
  names(df) <- tolower(trimws(gsub("\\s+", "_", names(df))))
  r1 <- tolower(as.character(unlist(df[1, ])))
  kw <- c("date", "age", "name", "address", "method", "camera", "closed", "notes")
  if (sum(r1 %in% kw) + sum(grepl("date|age|name|address|camera|closed", r1)) > 3) {
    hdr <- r1
    hdr <- gsub("\\s+", "_", gsub("\\*.*$", "", trimws(hdr)))
    hdr[hdr == "" | is.na(hdr)] <- paste0("col_", seq_along(hdr))[hdr == "" | is.na(hdr)]
    names(df) <- hdr
    df <- df[-1, , drop = FALSE]
  }
  yr <- if ("scrape_year" %in% names(df)) df$scrape_year else rep(NA_integer_, nrow(df))
  age_i    <- find_col(df, c("^age$", "victim.*age"))
  date_i   <- find_col(df, c("^date$", "date.*death", "incident.*date"))
  method_i <- find_col(df, c("^method$", "cause", "how", "manner"))
  camera_i <- find_col(df, c("^camera", "cctv"))
  status_i <- find_col(df, c("^closed$", "clear", "status", "arrest"))
  addr_i   <- find_col(df, c("^address$", "location", "block"))
  n <- nrow(df)
  out <- data.frame(
    year    = as.integer(yr),
    date    = as.Date(rep(NA, n)),
    age     = rep(NA_real_, n),
    method  = rep(NA_character_, n),
    camera  = rep(NA_character_, n),
    status  = rep(NA_character_, n),
    address = rep(NA_character_, n),
    stringsAsFactors = FALSE
  )
  if (!is.na(date_i))   out$date    <- as.Date(sapply(seq_len(n), function(i) parse_date(df[i, date_i], yr[i])), origin = "1970-01-01")
  if (!is.na(age_i))    out$age     <- sapply(df[[age_i]], extract_age)
  if (!is.na(method_i)) out$method  <- tolower(trimws(as.character(df[[method_i]])))
  if (!is.na(camera_i)) out$camera  <- trimws(as.character(df[[camera_i]]))
  if (!is.na(status_i)) out$status  <- trimws(as.character(df[[status_i]]))
  if (!is.na(addr_i))   out$address <- trimws(as.character(df[[addr_i]]))
  out <- out[!is.na(out$date) | !is.na(out$age), , drop = FALSE]
  out$month     <- as.integer(format(out$date, "%m"))
  out$month_lbl <- factor(format(out$date, "%b"), levels = month.abb)
  out
}

load_data <- function() {
  candidates <- c(
    "/srv/shiny-server/app/data/homicides_cache.csv",
    "data/homicides_cache.csv"
  )
  for (path in candidates) {
    if (file.exists(path)) {
      message("[DATA] Loading cache: ", path)
      df <- tryCatch(read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
      if (!is.null(df) && nrow(df) > 0) {
        if ("incident_date" %in% names(df) && !("date" %in% names(df)))
          names(df)[names(df) == "incident_date"] <- "date"
        if ("clearance_status" %in% names(df) && !("status" %in% names(df)))
          names(df)[names(df) == "clearance_status"] <- "status"
        if ("month_name" %in% names(df) && !("month_lbl" %in% names(df)))
          names(df)[names(df) == "month_name"] <- "month_lbl"
        if (!("month" %in% names(df)) && "month_num" %in% names(df))
          names(df)[names(df) == "month_num"] <- "month"
        df$date      <- as.Date(df$date)
        df$month_lbl <- factor(df$month_lbl, levels = month.abb)
        message("[DATA] Loaded ", nrow(df), " rows from cache.")
        return(df)
      }
    }
  }
  message("[DATA] No cache found. Scraping live from Cham's Page...")
  all_tables <- list()
  for (yr in names(URLS)) {
    tbl <- scrape_year(URLS[[yr]], yr)
    if (!is.null(tbl)) all_tables[[yr]] <- tbl
  }
  if (length(all_tables) == 0) {
    message("[DATA] Scraping failed for all years.")
    return(data.frame())
  }
  combined <- do.call(rbind, lapply(all_tables, function(t) {
    names(t) <- tolower(trimws(gsub("\\s+", "_", names(t))))
    t
  }))
  cleaned <- clean_table(combined)
  if (!is.null(cleaned) && nrow(cleaned) > 0) {
    cache_dir <- if (dir.exists("/srv/shiny-server/app")) "/srv/shiny-server/app/data" else "data"
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    tryCatch(write.csv(cleaned, file.path(cache_dir, "homicides_cache.csv"), row.names = FALSE),
             error = function(e) message("[DATA] Could not write cache: ", e$message))
    message("[DATA] Scraped and cached ", nrow(cleaned), " rows.")
    return(cleaned)
  }
  data.frame()
}

# ============================================================================
# LOAD & ENRICH DATA AT STARTUP
# ============================================================================

message("[STARTUP] Working directory: ", getwd())
HOMICIDES <- load_data()
message("[STARTUP] Loaded ", nrow(HOMICIDES), " total rows.")

# --- Enrich data for richer analysis ---
if (nrow(HOMICIDES) > 0) {
  # Standardise case status to Open / Closed
  HOMICIDES$case_status <- ifelse(
    grepl("closed|clear|arrest", tolower(HOMICIDES$status)), "Closed", "Open"
  )

  # Parse camera count from free-text camera field
  HOMICIDES$camera_count <- suppressWarnings(
    as.integer(str_extract(tolower(HOMICIDES$camera), "\\d+"))
  )
  HOMICIDES$camera_count[is.na(HOMICIDES$camera_count)] <- 0L
  HOMICIDES$camera_label <- ifelse(
    HOMICIDES$camera_count == 0, "No cameras",
    ifelse(HOMICIDES$camera_count == 1, "1 camera",
           paste0(HOMICIDES$camera_count, " cameras"))
  )

  # Day-of-year for cumulative pace chart
  HOMICIDES$day_of_year <- as.integer(format(HOMICIDES$date, "%j"))

  # Age group bins
  HOMICIDES$age_group <- cut(
    HOMICIDES$age,
    breaks = c(0, 17, 25, 35, 45, 55, Inf),
    labels = c("0-17", "18-25", "26-35", "36-45", "46-55", "56+"),
    right  = TRUE
  )

  # Extract street name for top-locations analysis
  HOMICIDES$street <- str_trim(str_replace(HOMICIDES$address, "^\\d+\\s*", ""))
}

# Compute safe ranges for UI
YEAR_CHOICES <- sort(unique(HOMICIDES$year[!is.na(HOMICIDES$year)]))
if (length(YEAR_CHOICES) == 0) YEAR_CHOICES <- c(2024L, 2025L)
AGE_MIN <- min(HOMICIDES$age, na.rm = TRUE)
AGE_MAX <- max(HOMICIDES$age, na.rm = TRUE)
if (!is.finite(AGE_MIN)) AGE_MIN <- 0
if (!is.finite(AGE_MAX)) AGE_MAX <- 100

MONTH_CHOICES <- setNames(1:12, month.abb)

# ============================================================================
# CUSTOM CSS
# ============================================================================

custom_css <- "
  .skin-black .main-header .logo { font-weight: bold; font-size: 16px; color: purple; }
  .content-wrapper { background-color: #2c3e50; color: #ecf0f5; }
  .small-box .inner h3 { font-size: 32px; color: #ffffff; }
  .small-box .inner p  { font-size: 13px; color: #ecf0f5; }
  .box.box-solid.box-primary > .box-header { background-color: #34495e; color: #ffffff; }
  .box.box-solid.box-info    > .box-header { background-color: #9b59b6; color: #ffffff; }
  .box.box-solid.box-success > .box-header { background-color: #e74c3c; color: #ffffff; }
  .box.box-solid.box-warning > .box-header { background-color: #f39c12; color: #ffffff; }
  .box { background-color: #34495e; color: #ecf0f5; border: 1px solid #7f8c8d; }
  .nav-tabs-custom > .tab-content { padding: 15px; background-color: #34495e; }
  .sidebar-menu li a { font-size: 14px; color: #ecf0f5; }
  .sidebar { background-color: #2c3e50; }
  #reset_filters { margin-top: 10px; background-color: #e74c3c; color: #ffffff; border-color: #c0392b; }
"

# ============================================================================
# UI
# ============================================================================

ui <- dashboardPage(
  skin = "black",
  dashboardHeader(title = "BPD Homicide Analysis"),
  dashboardSidebar(
    sidebarMenu(
      id = "tabs",
      menuItem("Command Brief",  tabName = "overview",     icon = icon("gauge-high")),
      menuItem("Trends",         tabName = "trends",       icon = icon("chart-line")),
      menuItem("Demographics",   tabName = "demographics", icon = icon("users")),
      menuItem("Case Records",   tabName = "records",      icon = icon("table"))
    ),
    hr(),
    h4("  Filters", style = "margin-left:15px; color:#b8c7ce;"),
    checkboxGroupInput("year_sel", "Year",
                       choices  = YEAR_CHOICES,
                       selected = YEAR_CHOICES),
    selectizeInput("month_sel", "Month",
                   choices  = MONTH_CHOICES,
                   selected = MONTH_CHOICES,
                   multiple = TRUE,
                   options  = list(placeholder = "All months")),
    sliderInput("age_range", "Victim age",
                min = AGE_MIN, max = AGE_MAX,
                value = c(AGE_MIN, AGE_MAX), step = 1),
    checkboxInput("inc_unk_age", "Include unknown ages", value = TRUE),
    selectInput("status_filter", "Case status",
                choices  = c("All", "Open", "Closed"),
                selected = "All"),
    selectInput("camera_filter", "Camera proximity",
                choices  = c("All", "No cameras", "1+ cameras"),
                selected = "All"),
    textInput("addr_search", "Address search",
              placeholder = "e.g. Windsor Mill Rd"),
    actionButton("reset_filters", "Reset All Filters",
                 icon = icon("rotate-left"), width = "90%",
                 class = "btn-sm btn-warning")
  ),
  dashboardBody(
    tags$head(tags$style(HTML(custom_css))),
    tabItems(

      # ── Command Brief ─────────────────────────────────────────────
      tabItem("overview",
        fluidRow(
          valueBoxOutput("vb_total",     width = 3),
          valueBoxOutput("vb_clearance", width = 3),
          valueBoxOutput("vb_median_age", width = 3),
          valueBoxOutput("vb_yoy",       width = 3)
        ),
        fluidRow(
          box(title = "Monthly Homicides by Year", status = "info",
              solidHeader = TRUE, width = 8,
              plotlyOutput("plot_monthly", height = "340px")),
          box(title = "Case Status Breakdown", status = "warning",
              solidHeader = TRUE, width = 4,
              plotlyOutput("plot_status_pie", height = "340px"))
        ),
        fluidRow(
          box(title = "Top 15 Locations", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("plot_locations", height = "340px")),
          box(title = "Yearly Comparison", status = "primary",
              solidHeader = TRUE, width = 6,
              plotlyOutput("plot_yearly", height = "340px"))
        )
      ),

      # ── Trends ────────────────────────────────────────────────────
      tabItem("trends",
        fluidRow(
          box(title = "Cumulative Homicides — Year-over-Year Pace",
              status = "warning", solidHeader = TRUE, width = 12,
              plotlyOutput("plot_cumulative", height = "380px"))
        ),
        fluidRow(
          box(title = "Camera Coverage Distribution", status = "info",
              solidHeader = TRUE, width = 6,
              plotlyOutput("plot_camera", height = "340px")),
          box(title = "Clearance Rate by Year", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("plot_clearance_yr", height = "340px"))
        )
      ),

      # ── Demographics ──────────────────────────────────────────────
      tabItem("demographics",
        fluidRow(
          valueBoxOutput("vb_youngest", width = 3),
          valueBoxOutput("vb_oldest",   width = 3),
          valueBoxOutput("vb_pct_u25",  width = 3),
          valueBoxOutput("vb_camera_pct", width = 3)
        ),
        fluidRow(
          box(title = "Age Distribution", status = "warning",
              solidHeader = TRUE, width = 6,
              plotlyOutput("plot_age_hist", height = "360px")),
          box(title = "Age Groups by Year", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("plot_age_group", height = "360px"))
        )
      ),

      # ── Case Records ──────────────────────────────────────────────
      tabItem("records",
        fluidRow(
          box(title = NULL, status = "warning", solidHeader = FALSE, width = 12,
              p(style = "margin-bottom:0;", 
                icon("info-circle"),
                "The table below shows all cases matching your sidebar filters.",
                "Click column headers to sort. Use the search box to find specific records."
              )
          )
        ),
        fluidRow(
          box(title = "Filtered Case Records", status = "warning",
              solidHeader = TRUE, width = 12, style = "background: white;",
              DT::DTOutput("tbl_data"))
        )
      )
    )
  )
)

# ============================================================================
# SERVER
# ============================================================================

server <- function(input, output, session) {

  # ── Reset button ──────────────────────────────────────────────────
  observeEvent(input$reset_filters, {
    updateCheckboxGroupInput(session, "year_sel",    selected = YEAR_CHOICES)
    updateSelectizeInput(session,     "month_sel",   selected = MONTH_CHOICES)
    updateSliderInput(session,        "age_range",   value = c(AGE_MIN, AGE_MAX))
    updateCheckboxInput(session,      "inc_unk_age", value = TRUE)
    updateSelectInput(session,        "status_filter", selected = "All")
    updateSelectInput(session,        "camera_filter", selected = "All")
    updateTextInput(session,          "addr_search", value = "")
  })

  # ── Central reactive filter ──────────────────────────────────────
  filt <- reactive({
    df <- HOMICIDES
    if (nrow(df) == 0) return(df)

    # Year
    sel_years <- as.integer(input$year_sel)
    if (length(sel_years) > 0)
      df <- df[!is.na(df$year) & df$year %in% sel_years, , drop = FALSE]

    # Month
    sel_months <- as.integer(input$month_sel)
    if (length(sel_months) > 0 && length(sel_months) < 12)
      df <- df[!is.na(df$month) & df$month %in% sel_months, , drop = FALSE]

    # Age
    if (isTRUE(input$inc_unk_age)) {
      df <- df[is.na(df$age) |
               (df$age >= input$age_range[1] & df$age <= input$age_range[2]), , drop = FALSE]
    } else {
      df <- df[!is.na(df$age) &
               df$age >= input$age_range[1] & df$age <= input$age_range[2], , drop = FALSE]
    }

    # Case status
    if (!is.null(input$status_filter) && input$status_filter != "All")
      df <- df[df$case_status == input$status_filter, , drop = FALSE]

    # Camera proximity
    if (!is.null(input$camera_filter) && input$camera_filter != "All") {
      if (input$camera_filter == "No cameras")
        df <- df[df$camera_count == 0, , drop = FALSE]
      else
        df <- df[df$camera_count >= 1, , drop = FALSE]
    }

    # Address search
    q <- trimws(input$addr_search)
    if (nchar(q) > 0)
      df <- df[grepl(q, df$address, ignore.case = TRUE), , drop = FALSE]

    df
  })

  # Helper: avoid repeating filt() calls in a single output
  n_filt <- reactive(nrow(filt()))

  # ==================================================================
  # COMMAND BRIEF — value boxes
  # ==================================================================

  output$vb_total <- renderValueBox({
    n <- n_filt()
    valueBox(format(n, big.mark = ","), "Filtered Homicides",
             icon = icon("crosshairs"),
             color = if (n == 0) "yellow" else "red")
  })

  output$vb_clearance <- renderValueBox({
    df <- filt()
    if (nrow(df) == 0) return(valueBox("—", "Clearance Rate", icon = icon("scale-balanced"), color = "yellow"))
    cleared <- sum(df$case_status == "Closed")
    rate <- round(100 * cleared / nrow(df), 1)
    valueBox(paste0(rate, "%"), "Clearance Rate",
             icon = icon("scale-balanced"),
             color = if (rate >= 50) "green" else "orange")
  })

  output$vb_median_age <- renderValueBox({
    ages <- filt()$age[!is.na(filt()$age)]
    if (length(ages) == 0) return(valueBox("—", "Median Victim Age", icon = icon("user"), color = "yellow"))
    valueBox(median(ages), "Median Victim Age",
             icon = icon("user"), color = "blue")
  })

  output$vb_yoy <- renderValueBox({
    df <- filt()
    yrs <- sort(unique(df$year))
    if (length(yrs) < 2) return(valueBox("—", "Year-over-Year Change", icon = icon("arrow-trend-up"), color = "navy"))
    curr <- sum(df$year == max(yrs))
    prev <- sum(df$year == max(yrs) - 1)
    if (prev == 0) return(valueBox("—", "Year-over-Year Change", icon = icon("arrow-trend-up"), color = "navy"))
    pct <- round(100 * (curr - prev) / prev, 1)
    lbl <- ifelse(pct >= 0, paste0("+", pct, "%"), paste0(pct, "%"))
    valueBox(lbl, paste0("vs. ", max(yrs) - 1),
             icon = icon(ifelse(pct >= 0, "arrow-up", "arrow-down")),
             color = ifelse(pct >= 0, "red", "green"))
  })

  # ==================================================================
  # COMMAND BRIEF — charts
  # ==================================================================

  output$plot_monthly <- renderPlotly({
    df <- filt()
    df <- df[!is.na(df$month_lbl) & !is.na(df$year), ]
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    agg <- as.data.frame(
      table(Month = df$month_lbl, Year = factor(df$year)),
      stringsAsFactors = FALSE
    )
    names(agg) <- c("Month", "Year", "Count")
    agg$Month <- factor(agg$Month, levels = month.abb)

    p <- ggplot(agg, aes(x = Month, y = Count, fill = Year)) +
      geom_col(position = "dodge") +
      scale_fill_manual(values = c("2024" = "#3498db", "2025" = "#e74c3c")) +
      labs(x = NULL, y = "Homicides") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top")
    ggplotly(p, tooltip = c("x", "fill", "y")) %>%
      layout(legend = list(orientation = "h", x = 0.3, y = 1.12))
  })

  output$plot_status_pie <- renderPlotly({
    df <- filt()
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    counts <- as.data.frame(table(Status = df$case_status), stringsAsFactors = FALSE)
    names(counts) <- c("Status", "Count")
    plot_ly(counts, labels = ~Status, values = ~Count, type = "pie",
            marker = list(colors = c("Closed" = "#27ae60", "Open" = "#e74c3c")),
            textinfo = "label+percent",
            hoverinfo = "label+value+percent") %>%
      layout(showlegend = FALSE)
  })

  output$plot_locations <- renderPlotly({
    df <- filt()
    df <- df[!is.na(df$street) & nchar(df$street) > 0, ]
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    st_counts <- sort(table(df$street), decreasing = TRUE)
    top <- head(st_counts, 15)
    top_df <- data.frame(Street = factor(names(top), levels = rev(names(top))),
                         Count = as.integer(top))

    p <- ggplot(top_df, aes(x = Count, y = Street)) +
      geom_col(fill = "#8e44ad") +
      labs(x = "Homicides", y = NULL) +
      theme_minimal(base_size = 12)
    ggplotly(p, tooltip = c("y", "x"))
  })

  output$plot_yearly <- renderPlotly({
    df <- filt()
    df <- df[!is.na(df$year), ]
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    agg <- as.data.frame(table(Year = factor(df$year)), stringsAsFactors = FALSE)
    names(agg) <- c("Year", "Count")

    p <- ggplot(agg, aes(x = Year, y = Count, fill = Year)) +
      geom_col(show.legend = FALSE) +
      geom_text(aes(label = Count), vjust = -0.5, size = 5) +
      scale_fill_manual(values = c("2024" = "#3498db", "2025" = "#e74c3c")) +
      labs(x = NULL, y = "Homicides") +
      theme_minimal(base_size = 13) +
      expand_limits(y = max(agg$Count) * 1.15)
    ggplotly(p, tooltip = c("x", "y"))
  })

  # ==================================================================
  # TRENDS
  # ==================================================================

  output$plot_cumulative <- renderPlotly({
    df <- filt()
    df <- df[!is.na(df$day_of_year) & !is.na(df$year), ]
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    # Build cumulative count per year
    cum_list <- lapply(split(df, df$year), function(sub) {
      sub <- sub[order(sub$day_of_year), ]
      sub$cum <- seq_len(nrow(sub))
      sub
    })
    cum_df <- do.call(rbind, cum_list)

    p <- ggplot(cum_df, aes(x = day_of_year, y = cum,
                            color = factor(year), group = factor(year))) +
      geom_line(linewidth = 1.1) +
      scale_color_manual(values = c("2024" = "#3498db", "2025" = "#e74c3c"),
                         name = "Year") +
      labs(x = "Day of Year", y = "Cumulative Homicides") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top")
    ggplotly(p, tooltip = c("x", "y", "colour")) %>%
      layout(legend = list(orientation = "h", x = 0.35, y = 1.12))
  })

  output$plot_camera <- renderPlotly({
    df <- filt()
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    cam_agg <- as.data.frame(table(Camera = df$camera_label), stringsAsFactors = FALSE)
    names(cam_agg) <- c("Camera", "Count")
    cam_agg$Camera <- factor(cam_agg$Camera,
                             levels = c("No cameras", "1 camera", "2 cameras", "3 cameras"))
    cam_agg <- cam_agg[order(cam_agg$Camera), ]

    p <- ggplot(cam_agg, aes(x = Camera, y = Count, fill = Camera)) +
      geom_col(show.legend = FALSE) +
      scale_fill_manual(values = c("No cameras" = "#bdc3c7",
                                   "1 camera"   = "#f39c12",
                                   "2 cameras"  = "#e67e22",
                                   "3 cameras"  = "#d35400")) +
      labs(x = NULL, y = "Homicides") +
      theme_minimal(base_size = 13)
    ggplotly(p, tooltip = c("x", "y"))
  })

  output$plot_clearance_yr <- renderPlotly({
    df <- filt()
    df <- df[!is.na(df$year), ]
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    agg <- do.call(rbind, lapply(split(df, df$year), function(sub) {
      n_total   <- nrow(sub)
      n_cleared <- sum(sub$case_status == "Closed")
      data.frame(Year = sub$year[1],
                 Rate = round(100 * n_cleared / n_total, 1),
                 Cleared = n_cleared,
                 Total = n_total, stringsAsFactors = FALSE)
    }))

    p <- ggplot(agg, aes(x = factor(Year), y = Rate, fill = factor(Year))) +
      geom_col(show.legend = FALSE) +
      geom_text(aes(label = paste0(Rate, "%\n(", Cleared, "/", Total, ")")),
                vjust = -0.3, size = 4) +
      scale_fill_manual(values = c("2024" = "#27ae60", "2025" = "#2ecc71")) +
      labs(x = NULL, y = "Clearance Rate (%)") +
      theme_minimal(base_size = 13) +
      expand_limits(y = max(agg$Rate) * 1.25)
    ggplotly(p, tooltip = c("x", "y"))
  })

  # ==================================================================
  # DEMOGRAPHICS
  # ==================================================================

  output$vb_youngest <- renderValueBox({
    ages <- filt()$age[!is.na(filt()$age)]
    if (length(ages) == 0) return(valueBox("—", "Youngest Victim", icon = icon("child"), color = "yellow"))
    valueBox(min(ages), "Youngest Victim", icon = icon("child"), color = "purple")
  })

  output$vb_oldest <- renderValueBox({
    ages <- filt()$age[!is.na(filt()$age)]
    if (length(ages) == 0) return(valueBox("—", "Oldest Victim", icon = icon("person-cane"), color = "yellow"))
    valueBox(max(ages), "Oldest Victim", icon = icon("person-cane"), color = "purple")
  })

  output$vb_pct_u25 <- renderValueBox({
    ages <- filt()$age[!is.na(filt()$age)]
    if (length(ages) == 0) return(valueBox("—", "Under 25", icon = icon("child-reaching"), color = "yellow"))
    pct <- round(100 * sum(ages <= 25) / length(ages), 1)
    valueBox(paste0(pct, "%"), "Victims Under 25",
             icon = icon("child-reaching"), color = "orange")
  })

  output$vb_camera_pct <- renderValueBox({
    df <- filt()
    if (nrow(df) == 0) return(valueBox("—", "Near Camera", icon = icon("video"), color = "yellow"))
    pct <- round(100 * sum(df$camera_count >= 1) / nrow(df), 1)
    valueBox(paste0(pct, "%"), "Near a Camera",
             icon = icon("video"), color = "teal")
  })

  output$plot_age_hist <- renderPlotly({
    ages <- filt()$age[!is.na(filt()$age)]
    if (length(ages) == 0) return(plotly_empty() %>% layout(title = "No age data"))

    p <- ggplot(data.frame(Age = ages), aes(x = Age)) +
      geom_histogram(binwidth = 5, fill = "#2980b9", color = "white") +
      labs(x = "Age", y = "Count") +
      theme_minimal(base_size = 13)
    ggplotly(p, tooltip = c("x", "y"))
  })

  output$plot_age_group <- renderPlotly({
    df <- filt()
    df <- df[!is.na(df$age_group) & !is.na(df$year), ]
    if (nrow(df) == 0) return(plotly_empty() %>% layout(title = "No data"))

    agg <- as.data.frame(
      table(AgeGroup = df$age_group, Year = factor(df$year)),
      stringsAsFactors = FALSE
    )
    names(agg) <- c("AgeGroup", "Year", "Count")

    p <- ggplot(agg, aes(x = AgeGroup, y = Count, fill = Year)) +
      geom_col(position = "dodge") +
      scale_fill_manual(values = c("2024" = "#3498db", "2025" = "#e74c3c")) +
      labs(x = "Age Group", y = "Count") +
      theme_minimal(base_size = 13) +
      theme(legend.position = "top")
    ggplotly(p, tooltip = c("x", "fill", "y")) %>%
      layout(legend = list(orientation = "h", x = 0.3, y = 1.12))
  })

  # ==================================================================
  # CASE RECORDS
  # ==================================================================

  output$tbl_data <- DT::renderDT({
    df <- filt()
    # Select display columns
    display <- df[, c("year", "date", "age", "address",
                       "case_status", "camera_label"), drop = FALSE]
    names(display) <- c("Year", "Date", "Age", "Address", "Status", "Camera")
    datatable(display,
              rownames = FALSE,
              filter   = "top",
              options  = list(
                pageLength = 20,
                scrollX    = TRUE,
                dom        = "lftipr",
                order      = list(list(1, "desc"))
              )) %>%
      formatStyle("Status",
                  backgroundColor = styleEqual(c("Closed", "Open"),
                                               c("#d5f5e3", "#fadbd8")))
  })
}

shinyApp(ui, server)
