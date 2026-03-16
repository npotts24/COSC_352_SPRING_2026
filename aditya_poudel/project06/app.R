suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(plotly)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(rvest)
  library(DT)
})

# ==============================================================================
# DATA PIPELINE — robust multi-strategy scraper
# ==============================================================================
# Multiple candidate URLs per year — scraper tries each until one succeeds
URLS <- list(
  "2026" = c(
    "https://chamspage.blogspot.com/2026/01/2026-baltimore-city-homicide-list.html"
  ),
  "2025" = c(
    "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
  ),
  "2024" = c(
    "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
    "https://chamspage.blogspot.com/2024/01/baltimore-city-2024-homicide-list.html"
  ),
  "2023" = c(
    "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicides-list.html"
  )
)
CACHE_FILE <- "homicide_data_cache.rds"

# ── helpers ──────────────────────────────────────────────────────────────────
make_safe_names <- function(x) {
  x <- str_squish(as.character(x))
  x <- str_replace_all(x, "\\s+", "_")
  x <- str_replace_all(x, "[^A-Za-z0-9_]", "")
  x <- tolower(x)
  x[x == "" | is.na(x)] <- "col"
  make.unique(x, sep = "_")
}

parse_date_flex <- function(x) {
  x <- str_squish(as.character(x))
  # try common formats
  out <- suppressWarnings(mdy(x))
  bad <- is.na(out)
  out[bad] <- suppressWarnings(dmy(x[bad]))
  bad <- is.na(out)
  out[bad] <- suppressWarnings(ymd(x[bad]))
  bad <- is.na(out)
  out[bad] <- suppressWarnings(my(x[bad]))
  out
}

derive_method <- function(text) {
  t <- str_to_lower(text)
  case_when(
    str_detect(t, "shoot|shot\\b|gunshot|firearm|gun") ~ "Shooting",
    str_detect(t, "stabb|knife|blade|cut")             ~ "Stabbing",
    str_detect(t, "strangl|asphyx")                    ~ "Strangulation",
    str_detect(t, "beaten|blunt|bat\\b|bludgeon")      ~ "Blunt Force",
    str_detect(t, "vehicle|hit.and.run|auto")          ~ "Vehicle",
    TRUE ~ "Other/Unknown"
  )
}

derive_cctv <- function(text) {
  t <- str_squish(str_to_lower(as.character(text)))
  case_when(
    is.na(text) | t == "" | t == "na" ~ "No",
    str_detect(t, "[0-9]+\\s*camera|camera|cctv|yes|\\by\\b") ~ "Yes",
    str_detect(t, "^no$|^n$|^none$|^0$")                            ~ "No",
    TRUE ~ "No"   # blank = no camera nearby
  )
}

derive_closed <- function(text) {
  t <- str_squish(str_to_lower(as.character(text)))
  case_when(
    is.na(text) | t == "" | t == "na" ~ "Open",
    str_detect(t, "closed|cleared|arrested|charged|solved|close") ~ "Closed",
    str_detect(t, "^open$|unsolved|active|no arrest")             ~ "Open",
    TRUE ~ "Open"   # blank = not yet closed
  )
}

# ── main scraper: tries each candidate URL, table strategy then DOM fallback ──
scrape_year <- function(urls, year) {
  # Try each candidate URL until one returns data
  for (url in urls) {
    message("  Scraping: ", url)
    page <- tryCatch(read_html(url), error = function(e) {
      message("    fetch failed: ", conditionMessage(e)); return(NULL)
    })
    if (is.null(page)) next
    result <- scrape_page(page, as.integer(year))
    if (!is.null(result) && nrow(result) > 2) {
      message("    SUCCESS: ", nrow(result), " rows from ", url)
      return(result)
    }
    message("    Too few rows (", if(is.null(result)) 0 else nrow(result), "), trying next URL...")
  }
  message("  All URLs failed for year ", year)
  return(NULL)
}

scrape_page <- function(page, yr) {

  yr <- as.integer(yr)

  # ── Strategy 1: HTML tables ───────────────────────────────────────────
  tbls <- tryCatch(
    page |> html_elements("table") |> lapply(\(t) html_table(t, fill = TRUE)),
    error = function(e) list()
  )

  result <- NULL

  if (length(tbls) > 0) {
    # score every table: +100 if has date+age header, +rows
    scores <- sapply(tbls, function(df) {
      if (nrow(df) == 0) return(0)
      maxr <- min(20, nrow(df))
      has_hdr <- any(sapply(1:maxr, function(i) {
        txt <- tolower(paste(as.character(df[i,]), collapse=" "))
        str_detect(txt,"\\bdate\\b") & str_detect(txt,"\\bage\\b")
      }))
      (if(has_hdr) 100 else 0) + min(nrow(df), 500)
    })
    best <- tbls[[which.max(scores)]]

    # find header row
    hr <- NA_integer_
    maxr <- min(30, nrow(best))
    for (i in 1:maxr) {
      txt <- tolower(paste(as.character(best[i,]), collapse=" "))
      if (str_detect(txt,"\\bdate\\b") && str_detect(txt,"\\bage\\b")) { hr <- i; break }
    }

    if (!is.na(hr) && hr < nrow(best)) {
      hdr  <- best[hr,, drop=TRUE]
      data <- best[(hr+1):nrow(best),, drop=FALSE]
      names(data) <- make_safe_names(hdr)
      nms <- names(data)

      col_date   <- nms[str_detect(nms,"date")][1]
      col_age    <- nms[str_detect(nms,"^age$|_age")][1]
      col_name   <- nms[str_detect(nms,"^name$|victim|^name")][1]
      col_addr   <- nms[str_detect(nms,"address|location|block|street")][1]
      col_cctv   <- nms[str_detect(nms,"camera|cctv|surveil|intersection")][1]
      col_status <- nms[str_detect(nms,"closed|case_closed|case$")][1]

      if (!is.na(col_date) && !is.na(col_age) && !is.na(col_name)) {
        result <- data |>
          mutate(
            row_text   = apply(data, 1, \(r) paste(na.omit(as.character(r)), collapse=" ")),
            date_raw   = str_squish(as.character(.data[[col_date]])),
            name       = str_squish(as.character(.data[[col_name]])),
            age_raw    = str_squish(as.character(.data[[col_age]])),
            address    = if (!is.na(col_addr))   str_squish(as.character(.data[[col_addr]]))   else NA_character_,
            cctv_raw   = if (!is.na(col_cctv))   str_squish(as.character(.data[[col_cctv]]))   else row_text,
            status_raw = if (!is.na(col_status)) str_squish(as.character(.data[[col_status]])) else row_text
          ) |>
          mutate(
            date_died = parse_date_flex(date_raw),
            age       = suppressWarnings(as.numeric(gsub("[^0-9.]", "", age_raw)))
          ) |>
          filter(!is.na(date_died), !is.na(age), age >= 0, age <= 110) |>
          filter(year(date_died) == yr)

        message("    Table strategy: ", nrow(result), " rows")
        message("    Columns found — cctv: ", col_cctv, " | status: ", col_status)
      }
    }
  }

  # ── Strategy 2: parse <tr> elements directly from the DOM ────────────
  # Used when table strategy yields 0-2 rows (header-only or fallback)
  if (is.null(result) || nrow(result) <= 2) {
    message("    Trying DOM row strategy...")
    rows <- page |> html_elements("tr")
    parsed <- lapply(rows, function(row) {
      cells <- row |> html_elements("td,th") |> html_text(trim=TRUE)
      if (length(cells) < 3) return(NULL)
      paste(cells, collapse="\t")
    })
    parsed <- Filter(Negate(is.null), parsed)
    raw_text <- unlist(parsed)

    # Find which row looks like a header
    hdr_idx <- which(str_detect(tolower(raw_text), "\\bdate\\b") &
                     str_detect(tolower(raw_text), "\\bage\\b"))
    if (length(hdr_idx) == 0) {
      message("    DOM strategy: no header row found")
      return(result)
    }
    hdr_row   <- str_split(raw_text[hdr_idx[1]], "\t")[[1]]
    data_rows <- raw_text[(hdr_idx[1]+1):length(raw_text)]
    data_rows <- data_rows[nchar(str_trim(data_rows)) > 0]

    if (length(data_rows) == 0) return(result)

    # figure out which tab-column is date, name, age by header
    hdr_lower <- str_to_lower(str_squish(hdr_row))
    ci_date <- which(str_detect(hdr_lower, "date"))[1]
    ci_age  <- which(str_detect(hdr_lower, "^age$|\\bage\\b"))[1]
    ci_name <- which(str_detect(hdr_lower, "name|victim"))[1]
    ci_addr <- which(str_detect(hdr_lower, "address|location|block"))[1]

    if (any(is.na(c(ci_date, ci_age, ci_name)))) {
      message("    DOM strategy: can't map columns from header: ", paste(hdr_lower, collapse="|"))
      return(result)
    }

    df2 <- lapply(data_rows, function(r) {
      cells <- str_split(r, "\t")[[1]]
      if (length(cells) < max(ci_date, ci_age, ci_name, na.rm=TRUE)) return(NULL)
      list(
        date_raw = cells[ci_date],
        name     = cells[ci_name],
        age_raw  = cells[ci_age],
        address  = if (!is.na(ci_addr) && ci_addr <= length(cells)) cells[ci_addr] else NA_character_,
        row_text = paste(cells, collapse=" ")
      )
    })
    df2 <- bind_rows(Filter(Negate(is.null), df2))

    if (nrow(df2) > 0) {
      df2 <- df2 |>
        mutate(
          date_died = parse_date_flex(str_squish(date_raw)),
          age       = suppressWarnings(as.numeric(gsub("[^0-9.]", "", str_squish(age_raw))))
        ) |>
        filter(!is.na(date_died), !is.na(age), age >= 0, age <= 110) |>
        filter(year(date_died) == yr)
      message("    DOM strategy: ", nrow(df2), " rows")
      if (nrow(df2) > nrow(result %||% data.frame())) result <- df2
    }
  }

  if (is.null(result) || nrow(result) == 0) return(NULL)

  # ── Enrich ───────────────────────────────────────────────────────────
  result |>
    transmute(
      date_died,
      name      = str_squish(as.character(name)),
      age,
      address   = str_squish(as.character(address)),
      row_text  = str_squish(as.character(row_text)),
      method    = derive_method(row_text),
      cctv      = derive_cctv(cctv_raw),
      status    = derive_closed(status_raw),
      year      = yr,
      month     = month(date_died, label=TRUE, abbr=TRUE),
      month_num = month(date_died),
      week_day  = wday(date_died, label=TRUE, abbr=TRUE),
      quarter   = paste0("Q", quarter(date_died))
    )
}

# null-coalescing operator
`%||%` <- function(a, b) if (!is.null(a)) a else b

load_data <- function() {
  if (file.exists(CACHE_FILE)) {
    message("Loading from cache: ", CACHE_FILE)
    df <- readRDS(CACHE_FILE)
    message("  Cached rows: ", nrow(df))
    return(df)
  }
  message("Scraping live data from Cham's blog...")
  dfs <- lapply(names(URLS), function(yr) scrape_year(URLS[[yr]], yr))
  df  <- bind_rows(Filter(Negate(is.null), dfs))
  message("Total rows scraped: ", nrow(df))
  if (nrow(df) > 0) saveRDS(df, CACHE_FILE)
  df
}

ALL_DATA <- tryCatch(load_data(), error = function(e) {
  message("Data load failed: ", conditionMessage(e)); data.frame()
})

# Fallback only if truly nothing loaded
if (nrow(ALL_DATA) == 0) {
  message("WARNING: Using fallback stub data — scrape returned 0 rows")
  ALL_DATA <- data.frame(
    date_died=as.Date("2025-01-15"), name="Data unavailable", age=30L,
    address=NA_character_, row_text="", method="Shooting",
    cctv="Unknown", status="Unknown", year=2025L,
    month=factor("Jan",levels=month.abb), month_num=1L,
    week_day=factor("Mon"), quarter="Q1", stringsAsFactors=FALSE
  )
}

YEARS   <- sort(unique(ALL_DATA$year))
METHODS <- sort(unique(ALL_DATA$method))

# ==============================================================================
# UI
# ==============================================================================
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(
    title = span(icon("shield-halved"), " Baltimore Homicide Analysis"),
    titleWidth = 320
  ),
  dashboardSidebar(
    width = 260,
    sidebarMenu(
      menuItem("Overview",          tabName="overview", icon=icon("chart-bar")),
      menuItem("Trends Over Time",  tabName="trends",   icon=icon("chart-line")),
      menuItem("Patterns & Timing", tabName="patterns", icon=icon("calendar-days")),
      menuItem("Case Detail Table", tabName="table",    icon=icon("table"))
    ),
    hr(),
    h5("  Filters", style="color:#ccc; padding-left:10px; font-weight:600;"),
    checkboxGroupInput("sel_year",   "Year(s):",    choices=YEARS,   selected=YEARS),
    sliderInput("sel_age","Victim Age Range:", min=0, max=110, value=c(0,110), step=1),
    checkboxGroupInput("sel_method", "Method:",     choices=METHODS, selected=METHODS),
    checkboxGroupInput("sel_status", "Case Status:",
      choices=c("Closed","Open","Unknown"), selected=c("Closed","Open","Unknown")),
    checkboxGroupInput("sel_cctv", "CCTV Nearby:",
      choices=c("Yes","No","Unknown"), selected=c("Yes","No","Unknown")),
    hr(),
    actionButton("btn_refresh","Refresh Data",
      icon=icon("rotate"), class="btn-warning btn-sm",
      style="margin:0 10px; width:80%"),
    hr(),
    uiOutput("data_info")
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .skin-blue .main-header .logo{background-color:#1a3a5c;font-weight:700;}
      .skin-blue .main-header .navbar{background-color:#1a3a5c;}
      .skin-blue .main-sidebar{background-color:#22303f;}
      .skin-blue .sidebar-menu>li.active>a,
      .skin-blue .sidebar-menu>li:hover>a{background-color:#1a3a5c;border-left:3px solid #3a9fd8;}
      .content-wrapper{background-color:#f4f6f9;}
      .box{border-top:3px solid #1a3a5c;}
      .data-info{color:#aaa;font-size:0.78rem;padding:0 12px 10px;}
    "))),

    tabItems(

      # ── OVERVIEW ──────────────────────────────────────────────────────
      tabItem(tabName="overview",
        fluidRow(
          valueBoxOutput("vb_total",     width=3),
          valueBoxOutput("vb_clear",     width=3),
          valueBoxOutput("vb_avg_age",   width=3),
          valueBoxOutput("vb_cctv_pct",  width=3)
        ),
        fluidRow(
          valueBoxOutput("vb_top_method",width=3),
          valueBoxOutput("vb_top_month", width=3),
          valueBoxOutput("vb_open",      width=3),
          valueBoxOutput("vb_yoy",       width=3)
        ),
        fluidRow(
          box(title="Homicides by Method",     width=6, solidHeader=TRUE, status="primary", plotlyOutput("plt_method",  height=320)),
          box(title="Victim Age Distribution", width=6, solidHeader=TRUE, status="primary", plotlyOutput("plt_age",     height=320))
        ),
        fluidRow(
          box(title="Monthly Homicide Count",  width=8, solidHeader=TRUE, status="primary", plotlyOutput("plt_monthly", height=280)),
          box(title="Case Status Breakdown",   width=4, solidHeader=TRUE, status="primary", plotlyOutput("plt_status",  height=280))
        )
      ),

      # ── TRENDS ────────────────────────────────────────────────────────
      tabItem(tabName="trends",
        fluidRow(
          box(title="Year-over-Year Monthly Comparison", width=12, solidHeader=TRUE,
              status="primary", plotlyOutput("plt_yoy", height=380))
        ),
        fluidRow(
          box(title="Clearance Rate by Year & Method", width=6, solidHeader=TRUE,
              status="primary", plotlyOutput("plt_clear_method", height=340)),
          box(title="CCTV Coverage vs Clearance Rate",  width=6, solidHeader=TRUE,
              status="primary", plotlyOutput("plt_cctv_clear",   height=340))
        ),
        fluidRow(
          box(title="Age Distribution by Method (Violin)", width=12, solidHeader=TRUE,
              status="primary", plotlyOutput("plt_violin", height=340))
        )
      ),

      # ── PATTERNS ──────────────────────────────────────────────────────
      tabItem(tabName="patterns",
        fluidRow(
          box(title="Homicide Heatmap: Month × Day of Week", width=8,
              solidHeader=TRUE, status="primary", plotlyOutput("plt_heatmap", height=380)),
          box(title="Homicides by Day of Week", width=4,
              solidHeader=TRUE, status="primary", plotlyOutput("plt_dow", height=380))
        ),
        fluidRow(
          box(title="Homicides by Quarter",   width=4, solidHeader=TRUE,
              status="primary", plotlyOutput("plt_quarter", height=280)),
          box(title="Method Mix by Year (%)", width=8, solidHeader=TRUE,
              status="primary", plotlyOutput("plt_method_year", height=280))
        )
      ),

      # ── TABLE ─────────────────────────────────────────────────────────
      tabItem(tabName="table",
        fluidRow(
          box(title="Filtered Case Detail", width=12, solidHeader=TRUE,
              status="primary", DTOutput("tbl_cases"))
        )
      )
    )
  )
)

# ==============================================================================
# SERVER
# ==============================================================================
server <- function(input, output, session) {

  # Show row count in sidebar
  output$data_info <- renderUI({
    div(class="data-info",
      paste0("Loaded: ", nrow(ALL_DATA), " records across ",
             length(unique(ALL_DATA$year)), " year(s)")
    )
  })

  observeEvent(input$btn_refresh, {
    if (file.exists(CACHE_FILE)) file.remove(CACHE_FILE)
    showNotification("Re-scraping from web...", type="message", duration=5)
    new_data <- tryCatch(load_data(), error=function(e) NULL)
    if (!is.null(new_data) && nrow(new_data) > 0) {
      ALL_DATA <<- new_data
      YEARS   <<- sort(unique(ALL_DATA$year))
      METHODS <<- sort(unique(ALL_DATA$method))
      updateCheckboxGroupInput(session, "sel_year",   choices=YEARS,   selected=YEARS)
      updateCheckboxGroupInput(session, "sel_method", choices=METHODS, selected=METHODS)
      showNotification(paste0("Loaded ", nrow(ALL_DATA), " records."), type="message")
    } else {
      showNotification("Refresh failed — keeping existing data.", type="warning")
    }
  })

  fdata <- reactive({
    req(nrow(ALL_DATA) > 0)
    ALL_DATA |>
      filter(
        year   %in% as.integer(input$sel_year),
        age    >= input$sel_age[1], age <= input$sel_age[2],
        method %in% input$sel_method,
        status %in% input$sel_status,
        cctv   %in% input$sel_cctv
      )
  })

  safe_df <- reactive({
    df <- fdata()
    if (nrow(df) == 0) return(NULL)
    df
  })

  # ── VALUE BOXES ────────────────────────────────────────────────────────
  output$vb_total <- renderValueBox({
    n <- if (is.null(safe_df())) 0 else nrow(safe_df())
    valueBox(format(n, big.mark=","), "Total Homicides", icon=icon("circle-dot"), color="red")
  })
  output$vb_clear <- renderValueBox({
    df <- safe_df()
    pct <- if (is.null(df)) "—" else paste0(round(mean(df$status=="Closed")*100,1),"%")
    valueBox(pct, "Clearance Rate", icon=icon("gavel"), color="green")
  })
  output$vb_avg_age <- renderValueBox({
    df <- safe_df()
    val <- if (is.null(df)) "—" else round(mean(df$age, na.rm=TRUE),1)
    valueBox(val, "Avg Victim Age", icon=icon("person"), color="blue")
  })
  output$vb_cctv_pct <- renderValueBox({
    df <- safe_df()
    pct <- if (is.null(df)) "—" else paste0(round(mean(df$cctv=="Yes")*100,1),"%")
    valueBox(pct, "Near CCTV Camera", icon=icon("video"), color="purple")
  })
  output$vb_top_method <- renderValueBox({
    df <- safe_df()
    val <- if (is.null(df)) "—" else df |> count(method,sort=TRUE) |> slice(1) |> pull(method)
    valueBox(val, "Top Method", icon=icon("gun"), color="orange")
  })
  output$vb_top_month <- renderValueBox({
    df <- safe_df()
    val <- if (is.null(df)) "—" else as.character(df |> count(month,sort=TRUE) |> slice(1) |> pull(month))
    valueBox(val, "Deadliest Month", icon=icon("calendar"), color="yellow")
  })
  output$vb_open <- renderValueBox({
    df <- safe_df()
    n <- if (is.null(df)) 0 else sum(df$status=="Open")
    valueBox(n, "Open Cases", icon=icon("folder-open"), color="maroon")
  })
  output$vb_yoy <- renderValueBox({
    df <- safe_df()
    val <- if (is.null(df)||length(unique(df$year))<2) "N/A" else {
      yrs <- tail(sort(unique(df$year)),2)
      n1 <- sum(df$year==yrs[1]); n2 <- sum(df$year==yrs[2])
      if (n1==0) "N/A" else {
        chg <- round((n2-n1)/n1*100,1)
        paste0(ifelse(chg>=0,"+",""),chg,"%")
      }
    }
    valueBox(val, "YoY Change", icon=icon("arrow-trend-up"), color="navy")
  })

  # ── OVERVIEW CHARTS ────────────────────────────────────────────────────
  output$plt_method <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> count(method, sort=TRUE)
    plot_ly(tbl, x=~reorder(method,n), y=~n, type="bar",
            marker=list(color="#1a6faf"), text=~n, textposition="outside") |>
      layout(xaxis=list(title="Method"), yaxis=list(title="Count"), margin=list(b=80))
  })
  output$plt_age <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    plot_ly(df, x=~age, type="histogram", nbinsx=22,
            marker=list(color="#e05c2a", line=list(color="#fff",width=0.5))) |>
      layout(xaxis=list(title="Victim Age"), yaxis=list(title="Count"))
  })
  output$plt_monthly <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> count(year, month_num, month) |> arrange(year, month_num)
    plot_ly(tbl, x=~month, y=~n, color=~factor(year),
            type="scatter", mode="lines+markers", line=list(width=2)) |>
      layout(xaxis=list(title="Month"), yaxis=list(title="Homicides"),
             legend=list(title=list(text="Year")))
  })
  output$plt_status <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> count(status)
    cols <- c("Closed"="#2ecc71","Open"="#e74c3c","Unknown"="#95a5a6")
    plot_ly(tbl, labels=~status, values=~n, type="pie",
            marker=list(colors=unname(cols[tbl$status])),
            textinfo="label+percent")
  })

  # ── TRENDS CHARTS ──────────────────────────────────────────────────────
  output$plt_yoy <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> count(year, month_num, month) |> arrange(year, month_num)
    plot_ly(tbl, x=~month_num, y=~n, color=~factor(year),
            type="scatter", mode="lines+markers", line=list(width=2.5)) |>
      layout(xaxis=list(title="Month", tickmode="array",
                        tickvals=1:12, ticktext=month.abb),
             yaxis=list(title="Homicides"),
             legend=list(title=list(text="Year")), hovermode="x unified")
  })
  output$plt_clear_method <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> group_by(year, method) |>
      summarise(rate=round(mean(status=="Closed")*100,1), .groups="drop")
    plot_ly(tbl, x=~method, y=~rate, color=~factor(year), type="bar", barmode="group") |>
      layout(xaxis=list(title="Method"),
             yaxis=list(title="Clearance Rate (%)", range=c(0,100)),
             legend=list(title=list(text="Year")))
  })
  output$plt_cctv_clear <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> group_by(cctv) |>
      summarise(total=n(), rate=round(mean(status=="Closed")*100,1), .groups="drop")
    plot_ly(tbl, x=~cctv, y=~rate, type="bar",
            text=~paste0(rate,"%"), textposition="outside",
            marker=list(color=c("#3498db","#e74c3c","#95a5a6"))) |>
      layout(xaxis=list(title="CCTV Nearby"),
             yaxis=list(title="Clearance Rate (%)", range=c(0,115)))
  })
  output$plt_violin <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    plot_ly(df, x=~method, y=~age, type="violin",
            box=list(visible=TRUE), meanline=list(visible=TRUE), color=~method) |>
      layout(xaxis=list(title="Method"), yaxis=list(title="Victim Age"), showlegend=FALSE)
  })

  # ── PATTERNS CHARTS ────────────────────────────────────────────────────
  output$plt_heatmap <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    dow_order <- c("Mon","Tue","Wed","Thu","Fri","Sat","Sun")
    tbl <- df |>
      mutate(week_day=factor(as.character(week_day), levels=dow_order),
             month=factor(as.character(month), levels=month.abb)) |>
      count(month, week_day) |>
      tidyr::complete(month, week_day, fill=list(n=0))
    mat  <- tidyr::pivot_wider(tbl, names_from=week_day, values_from=n, values_fill=0)
    zmat <- as.matrix(mat[,-1])
    plot_ly(x=dow_order, y=as.character(mat$month), z=zmat,
            type="heatmap", colorscale="Reds",
            hovertemplate="%{y} %{x}: %{z} homicides<extra></extra>") |>
      layout(xaxis=list(title="Day of Week"), yaxis=list(title="Month"))
  })
  output$plt_dow <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    dow_order <- c("Mon","Tue","Wed","Thu","Fri","Sat","Sun")
    tbl <- df |>
      mutate(week_day=factor(as.character(week_day), levels=dow_order)) |>
      count(week_day) |> arrange(week_day)
    plot_ly(tbl, x=~week_day, y=~n, type="bar",
            marker=list(color="#8e44ad")) |>
      layout(xaxis=list(title="Day of Week"), yaxis=list(title="Homicides"))
  })
  output$plt_quarter <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> count(quarter) |> arrange(quarter)
    plot_ly(tbl, x=~quarter, y=~n, type="bar",
            marker=list(color=c("#1abc9c","#e67e22","#3498db","#e74c3c")[seq_len(nrow(tbl))])) |>
      layout(xaxis=list(title="Quarter"), yaxis=list(title="Homicides"))
  })
  output$plt_method_year <- renderPlotly({
    df <- safe_df(); if (is.null(df)) return(plotly_empty())
    tbl <- df |> count(year, method) |>
      group_by(year) |> mutate(pct=round(n/sum(n)*100,1)) |> ungroup()
    plot_ly(tbl, x=~factor(year), y=~pct, color=~method,
            type="bar", barmode="stack",
            text=~paste0(pct,"%"), textposition="inside") |>
      layout(xaxis=list(title="Year"), yaxis=list(title="Share (%)"),
             legend=list(title=list(text="Method")))
  })

  # ── DATA TABLE ─────────────────────────────────────────────────────────
  output$tbl_cases <- renderDT({
    df <- safe_df()
    if (is.null(df)) return(datatable(data.frame(Message="No data matches current filters.")))
    df |>
      select(Date=date_died, Name=name, Age=age, Method=method,
             Status=status, CCTV=cctv, Year=year, Address=address) |>
      arrange(desc(Date)) |>
      datatable(
        options=list(pageLength=25, scrollX=TRUE, dom="Bfrtip",
                     buttons=c("csv","excel")),
        extensions="Buttons", filter="top",
        rownames=FALSE, class="stripe hover compact"
      )
  })
}

shinyApp(ui=ui, server=server)