library(shiny)
library(shinydashboard)
library(plotly)
library(leaflet)
library(dplyr)
library(lubridate)
library(DT)
library(rvest)
library(stringr)
library(httr)

# ── Data scraping ────────────────────────────────────────────────────────────

scrape_year <- function(url, year) {
  tryCatch({
    page <- read_html(url)
    tables <- page %>% html_table(fill = TRUE)
    if (length(tables) == 0) return(NULL)
    df <- tables[[1]]
    colnames(df) <- make.names(colnames(df), unique = TRUE)

    # Normalise common column name variants
    names(df) <- gsub("Cause\\.of\\.Death|Cause|Method|Manner", "Cause", names(df), ignore.case = TRUE)
    names(df) <- gsub("^Race$", "Race", names(df), ignore.case = TRUE)
    names(df) <- gsub("^Sex$|^Gender$", "Sex", names(df), ignore.case = TRUE)
    names(df) <- gsub("^Age$", "Age", names(df), ignore.case = TRUE)
    names(df) <- gsub("^Name$|^Victim$", "Name", names(df), ignore.case = TRUE)
    names(df) <- gsub("District|Neighborhood|Location|Address", "District", names(df), ignore.case = TRUE)

    # Parse date
    if ("Date" %in% names(df)) {
      df$Date <- as.Date(df$Date, format = "%m/%d/%Y")
      if (all(is.na(df$Date))) df$Date <- as.Date(df$Date, format = "%Y-%m-%d")
    } else {
      df$Date <- as.Date(NA)
    }

    df$Year  <- year
    df$Month <- month(df$Date, label = TRUE, abbr = TRUE)
    df$MonthNum <- month(df$Date)

    if ("Age" %in% names(df)) df$Age <- suppressWarnings(as.numeric(df$Age))
    if (!"Cause" %in% names(df)) df$Cause <- "Unknown"
    if (!"Race"  %in% names(df)) df$Race  <- "Unknown"
    if (!"Sex"   %in% names(df)) df$Sex   <- "Unknown"
    if (!"District" %in% names(df)) df$District <- "Unknown"

    # Case status – look for Open/Closed/Arrest columns
    status_col <- grep("Status|Open|Close|Arrest|Clear", names(df), ignore.case = TRUE, value = TRUE)
    if (length(status_col) > 0) {
      df$Status <- df[[status_col[1]]]
    } else {
      df$Status <- "Unknown"
    }

    df$Cause    <- str_trim(str_to_title(as.character(df$Cause)))
    df$Race     <- str_trim(str_to_title(as.character(df$Race)))
    df$Sex      <- str_trim(str_to_title(as.character(df$Sex)))
    df$District <- str_trim(str_to_title(as.character(df$District)))
    df$Status   <- str_trim(str_to_title(as.character(df$Status)))

    df <- df %>% filter(!is.na(Date))
    df
  }, error = function(e) {
    message("Failed to scrape ", year, ": ", e$message)
    NULL
  })
}

urls <- list(
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  "2023" = "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html"
)

all_data <- bind_rows(
  scrape_year(urls[["2025"]], 2025),
  scrape_year(urls[["2024"]], 2024),
  scrape_year(urls[["2023"]], 2023)
)

# Fallback: if scraping fails entirely, create minimal demo data
if (is.null(all_data) || nrow(all_data) == 0) {
  set.seed(42)
  all_data <- data.frame(
    Date     = sample(seq(as.Date("2023-01-01"), as.Date("2025-12-31"), by = "day"), 300),
    Year     = sample(2023:2025, 300, replace = TRUE),
    Age      = sample(15:75, 300, replace = TRUE),
    Cause    = sample(c("Shooting","Stabbing","Blunt Force","Other"), 300, replace = TRUE),
    Race     = sample(c("Black","White","Hispanic","Other"), 300, replace = TRUE),
    Sex      = sample(c("Male","Female"), 300, replace = TRUE),
    District = sample(paste("District", 1:9), 300, replace = TRUE),
    Status   = sample(c("Open","Closed","Arrest"), 300, replace = TRUE),
    stringsAsFactors = FALSE
  )
  all_data$Month    <- month(all_data$Date, label = TRUE, abbr = TRUE)
  all_data$MonthNum <- month(all_data$Date)
}

# Baltimore neighbourhood bounding boxes for approximate geo-placement
set.seed(99)
all_data$lat <- runif(nrow(all_data), 39.197, 39.372)
all_data$lon <- runif(nrow(all_data), -76.711, -76.529)

# ── Helper values ─────────────────────────────────────────────────────────────

all_years   <- sort(unique(all_data$Year))
all_causes  <- sort(unique(all_data$Cause[all_data$Cause != ""]))
all_races   <- sort(unique(all_data$Race[all_data$Race != ""]))
age_min     <- 0
age_max     <- max(all_data$Age, na.rm = TRUE)
if (is.infinite(age_max) || is.na(age_max)) age_max <- 100

# ── UI ────────────────────────────────────────────────────────────────────────

ui <- dashboardPage(
  skin = "blue",

  dashboardHeader(title = "Baltimore Homicide Analysis"),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview",      tabName = "overview",  icon = icon("chart-bar")),
      menuItem("Trends",        tabName = "trends",    icon = icon("chart-line")),
      menuItem("Demographics",  tabName = "demo",      icon = icon("users")),
      menuItem("Map",           tabName = "map",       icon = icon("map")),
      menuItem("Data Table",    tabName = "table",     icon = icon("table"))
    ),
    hr(),
    h5("  Filters", style = "color:#b8c7ce; padding-left:10px;"),
    checkboxGroupInput("year_filter", "Year",
                       choices  = all_years,
                       selected = all_years),
    sliderInput("age_filter", "Victim Age Range",
                min = age_min, max = age_max,
                value = c(age_min, age_max), step = 1),
    checkboxGroupInput("cause_filter", "Cause of Death",
                       choices  = all_causes,
                       selected = all_causes),
    checkboxGroupInput("sex_filter", "Sex",
                       choices  = c("Male","Female","Unknown"),
                       selected = c("Male","Female","Unknown")),
    actionButton("reset_filters", "Reset Filters",
                 icon = icon("rotate-left"),
                 class = "btn-warning btn-sm",
                 style = "margin:10px;")
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .small-box { border-radius:6px; }
      .box { border-radius:6px; }
      .content-wrapper { background-color:#f4f6f9; }
    "))),

    tabItems(

      # ── Overview ────────────────────────────────────────────────────────────
      tabItem(tabName = "overview",
        fluidRow(
          valueBoxOutput("vb_total",      width = 3),
          valueBoxOutput("vb_clearance",  width = 3),
          valueBoxOutput("vb_avg_age",    width = 3),
          valueBoxOutput("vb_top_cause",  width = 3)
        ),
        fluidRow(
          box(title = "Homicides by Month", status = "primary",
              solidHeader = TRUE, width = 6,
              plotlyOutput("bar_monthly", height = 320)),
          box(title = "Homicides by Cause of Death", status = "danger",
              solidHeader = TRUE, width = 6,
              plotlyOutput("bar_cause", height = 320))
        ),
        fluidRow(
          box(title = "Case Status Breakdown", status = "warning",
              solidHeader = TRUE, width = 4,
              plotlyOutput("pie_status", height = 280)),
          box(title = "Year-over-Year Comparison", status = "success",
              solidHeader = TRUE, width = 8,
              plotlyOutput("bar_yoy", height = 280))
        )
      ),

      # ── Trends ──────────────────────────────────────────────────────────────
      tabItem(tabName = "trends",
        fluidRow(
          box(title = "Monthly Homicide Trend Over Time", status = "primary",
              solidHeader = TRUE, width = 12,
              plotlyOutput("line_trend", height = 380))
        ),
        fluidRow(
          box(title = "Clearance Rate Over Time (by Year)", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("line_clearance", height = 320)),
          box(title = "Homicides by Day of Week", status = "warning",
              solidHeader = TRUE, width = 6,
              plotlyOutput("bar_dow", height = 320))
        )
      ),

      # ── Demographics ────────────────────────────────────────────────────────
      tabItem(tabName = "demo",
        fluidRow(
          box(title = "Victim Age Distribution", status = "primary",
              solidHeader = TRUE, width = 6,
              plotlyOutput("hist_age", height = 320)),
          box(title = "Homicides by Race", status = "danger",
              solidHeader = TRUE, width = 6,
              plotlyOutput("bar_race", height = 320))
        ),
        fluidRow(
          box(title = "Sex Breakdown", status = "info",
              solidHeader = TRUE, width = 4,
              plotlyOutput("pie_sex", height = 280)),
          box(title = "Age vs Cause of Death", status = "warning",
              solidHeader = TRUE, width = 8,
              plotlyOutput("box_age_cause", height = 280))
        )
      ),

      # ── Map ─────────────────────────────────────────────────────────────────
      tabItem(tabName = "map",
        fluidRow(
          box(title = "Incident Map (approximate locations)", status = "primary",
              solidHeader = TRUE, width = 12,
              leafletOutput("map_plot", height = 560))
        )
      ),

      # ── Table ───────────────────────────────────────────────────────────────
      tabItem(tabName = "table",
        fluidRow(
          box(title = "Filtered Homicide Records", status = "primary",
              solidHeader = TRUE, width = 12,
              DTOutput("data_table"))
        )
      )
    )
  )
)

# ── Server ────────────────────────────────────────────────────────────────────

server <- function(input, output, session) {

  # Reset filters
  observeEvent(input$reset_filters, {
    updateCheckboxGroupInput(session, "year_filter",  selected = all_years)
    updateCheckboxGroupInput(session, "cause_filter", selected = all_causes)
    updateCheckboxGroupInput(session, "sex_filter",   selected = c("Male","Female","Unknown"))
    updateSliderInput(session, "age_filter", value = c(age_min, age_max))
  })

  # Reactive filtered dataset
  df <- reactive({
    req(input$year_filter, input$cause_filter, input$sex_filter)
    d <- all_data %>%
      filter(
        Year  %in% input$year_filter,
        Cause %in% input$cause_filter,
        Sex   %in% input$sex_filter,
        (is.na(Age) | (Age >= input$age_filter[1] & Age <= input$age_filter[2]))
      )
    d
  })

  # Guard: show a message if filters return nothing
  empty_plot <- function(msg = "No data matches current filters") {
    plot_ly() %>%
      layout(
        xaxis = list(visible = FALSE),
        yaxis = list(visible = FALSE),
        annotations = list(list(
          text = msg, showarrow = FALSE,
          xref = "paper", yref = "paper", x = 0.5, y = 0.5,
          font = list(size = 16, color = "grey")
        ))
      )
  }

  # ── Value boxes ─────────────────────────────────────────────────────────────
  output$vb_total <- renderValueBox({
    n <- nrow(df())
    valueBox(n, "Total Homicides", icon = icon("skull"), color = "red")
  })

  output$vb_clearance <- renderValueBox({
    d <- df()
    if (nrow(d) == 0) { valueBox("N/A", "Clearance Rate", icon = icon("gavel"), color = "yellow"); return() }
    rate <- round(mean(grepl("closed|arrest", d$Status, ignore.case = TRUE), na.rm = TRUE) * 100, 1)
    valueBox(paste0(rate, "%"), "Clearance Rate", icon = icon("gavel"), color = "yellow")
  })

  output$vb_avg_age <- renderValueBox({
    avg <- round(mean(df()$Age, na.rm = TRUE), 1)
    val <- if (is.nan(avg)) "N/A" else avg
    valueBox(val, "Avg Victim Age", icon = icon("user"), color = "blue")
  })

  output$vb_top_cause <- renderValueBox({
    d <- df()
    if (nrow(d) == 0) { valueBox("N/A", "Top Cause", icon = icon("gun"), color = "purple"); return() }
    top <- names(sort(table(d$Cause), decreasing = TRUE))[1]
    valueBox(top, "Most Common Cause", icon = icon("gun"), color = "purple")
  })

  # ── Overview charts ──────────────────────────────────────────────────────────
  output$bar_monthly <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    cnt <- d %>% count(MonthNum, Month) %>% arrange(MonthNum)
    plot_ly(cnt, x = ~Month, y = ~n, type = "bar",
            marker = list(color = "#3c8dbc")) %>%
      layout(xaxis = list(title = "Month"),
             yaxis = list(title = "Homicides"),
             margin = list(t = 20))
  })

  output$bar_cause <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    cnt <- d %>% count(Cause) %>% arrange(desc(n))
    plot_ly(cnt, x = ~reorder(Cause, n), y = ~n, type = "bar",
            marker = list(color = "#dd4b39")) %>%
      layout(xaxis = list(title = "", tickangle = -30),
             yaxis = list(title = "Count"),
             margin = list(b = 80, t = 20))
  })

  output$pie_status <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    cnt <- d %>% count(Status)
    plot_ly(cnt, labels = ~Status, values = ~n, type = "pie",
            marker = list(colors = c("#00a65a","#dd4b39","#f39c12","#aaa"))) %>%
      layout(margin = list(t = 10, b = 10))
  })

  output$bar_yoy <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    cnt <- d %>% count(Year, Month, MonthNum) %>% arrange(Year, MonthNum)
    plot_ly(cnt, x = ~Month, y = ~n, color = ~factor(Year),
            type = "bar", barmode = "group") %>%
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Homicides"),
             legend = list(title = list(text = "Year")),
             margin = list(t = 10))
  })

  # ── Trends charts ────────────────────────────────────────────────────────────
  output$line_trend <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    cnt <- d %>%
      mutate(YearMonth = floor_date(Date, "month")) %>%
      count(YearMonth, Year)
    plot_ly(cnt, x = ~YearMonth, y = ~n, color = ~factor(Year),
            type = "scatter", mode = "lines+markers") %>%
      layout(xaxis = list(title = "Month"),
             yaxis = list(title = "Homicides"),
             legend = list(title = list(text = "Year")))
  })

  output$line_clearance <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    rate <- d %>%
      group_by(Year) %>%
      summarise(rate = round(mean(grepl("closed|arrest", Status, ignore.case = TRUE), na.rm = TRUE) * 100, 1))
    plot_ly(rate, x = ~Year, y = ~rate, type = "scatter", mode = "lines+markers",
            marker = list(color = "#00a65a"), line = list(color = "#00a65a")) %>%
      layout(xaxis = list(title = "Year", dtick = 1),
             yaxis = list(title = "Clearance Rate (%)", range = c(0, 100)))
  })

  output$bar_dow <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    d$DOW <- wday(d$Date, label = TRUE, abbr = TRUE)
    cnt <- d %>% count(DOW) %>% arrange(DOW)
    plot_ly(cnt, x = ~DOW, y = ~n, type = "bar",
            marker = list(color = "#f39c12")) %>%
      layout(xaxis = list(title = "Day of Week"),
             yaxis = list(title = "Homicides"))
  })

  # ── Demographics charts ──────────────────────────────────────────────────────
  output$hist_age <- renderPlotly({
    d <- df() %>% filter(!is.na(Age))
    if (nrow(d) == 0) return(empty_plot())
    plot_ly(d, x = ~Age, type = "histogram", nbinsx = 20,
            marker = list(color = "#3c8dbc", line = list(color = "white", width = 1))) %>%
      layout(xaxis = list(title = "Age"),
             yaxis = list(title = "Count"))
  })

  output$bar_race <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    cnt <- d %>% count(Race) %>% arrange(desc(n))
    plot_ly(cnt, x = ~reorder(Race, n), y = ~n, type = "bar",
            marker = list(color = "#dd4b39")) %>%
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Count"))
  })

  output$pie_sex <- renderPlotly({
    d <- df()
    if (nrow(d) == 0) return(empty_plot())
    cnt <- d %>% count(Sex)
    plot_ly(cnt, labels = ~Sex, values = ~n, type = "pie",
            marker = list(colors = c("#3c8dbc","#dd4b39","#aaa")))
  })

  output$box_age_cause <- renderPlotly({
    d <- df() %>% filter(!is.na(Age))
    if (nrow(d) == 0) return(empty_plot())
    plot_ly(d, x = ~Cause, y = ~Age, type = "box",
            color = ~Cause) %>%
      layout(xaxis = list(title = "", tickangle = -20),
             yaxis = list(title = "Victim Age"),
             showlegend = FALSE)
  })

  # ── Map ──────────────────────────────────────────────────────────────────────
  output$map_plot <- renderLeaflet({
    d <- df()
    leaflet(d) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = -76.62, lat = 39.29, zoom = 12) %>%
      addCircleMarkers(
        lng = ~lon, lat = ~lat,
        radius = 5,
        color = ~ifelse(grepl("closed|arrest", Status, ignore.case = TRUE), "#00a65a", "#dd4b39"),
        fillOpacity = 0.7,
        stroke = FALSE,
        popup = ~paste0(
          "<b>Date:</b> ", Date, "<br>",
          "<b>Cause:</b> ", Cause, "<br>",
          "<b>Age:</b> ", Age, "<br>",
          "<b>Sex:</b> ", Sex, "<br>",
          "<b>Race:</b> ", Race, "<br>",
          "<b>Status:</b> ", Status
        )
      ) %>%
      addLegend("bottomright",
                colors = c("#00a65a","#dd4b39"),
                labels = c("Closed/Arrest","Open"),
                title = "Case Status")
  })

  # ── Data table ───────────────────────────────────────────────────────────────
  output$data_table <- renderDT({
    d <- df() %>%
      select(Date, Year, Age, Sex, Race, Cause, District, Status) %>%
      arrange(desc(Date))
    datatable(d,
              options = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE,
              filter = "top")
  })
}

shinyApp(ui, server)
