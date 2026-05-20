# app.R - Baltimore City Homicide Analysis Dashboard
# Shiny application for interactive homicide data analysis

# Load required packages
library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(ggplot2)
library(lubridate)
library(rvest)
library(stringr)
library(tidyr)

# Data scraping and processing functions
scrape_homicide_data <- function(url, year) {
  cat(sprintf("Scraping %s data from: %s\n", year, url))

  tryCatch({
    page <- read_html(url)
    tables <- page %>% html_table(fill = TRUE)

    if (length(tables) == 0) {
      cat(sprintf("Warning: No tables found on page for %s\n", year))
      return(NULL)
    }

    data <- NULL
    for (i in seq_along(tables)) {
      table_df <- tables[[i]]
      if (nrow(table_df) > 5 && ncol(table_df) >= 3) {
        data <- table_df
        break
      }
    }

    if (is.null(data)) {
      cat(sprintf("Warning: Could not find a suitable table for %s\n", year))
      return(NULL)
    }

    names(data) <- tolower(trimws(names(data)))
    data$year <- year
    return(as.data.frame(data))

  }, error = function(e) {
    cat(sprintf("Error scraping %s: %s\n", year, e$message))
    return(NULL)
  })
}

clean_homicide_data <- function(df) {
  # Normalize column names
  names(df) <- tolower(trimws(names(df)))

  # Find relevant columns
  age_col <- names(df)[grepl("age", names(df), ignore.case = TRUE)][1]
  date_col <- names(df)[grepl("date|incident", names(df), ignore.case = TRUE)][1]
  method_col <- names(df)[grepl("method|cause", names(df), ignore.case = TRUE)][1]
  location_col <- names(df)[grepl("location|address|area", names(df), ignore.case = TRUE)][1]
  cctv_col <- names(df)[grepl("cctv|camera|surveillance", names(df), ignore.case = TRUE)][1]
  status_col <- names(df)[grepl("status|cleared|solved", names(df), ignore.case = TRUE)][1]

  # Extract age
  if (!is.na(age_col)) {
    df$age <- as.numeric(gsub("[^0-9]", "", df[[age_col]]))
  }

  # Extract date
  if (!is.na(date_col)) {
    df$date <- parse_date_time(df[[date_col]], orders = c("mdy", "ymd", "dmy"))
    df$month <- month(df$date)
    df$month_name <- month(df$date, label = TRUE)
  }

  # Extract method
  if (!is.na(method_col)) {
    df$method <- tolower(trimws(df[[method_col]]))
  }

  # Extract location
  if (!is.na(location_col)) {
    df$location <- trimws(df[[location_col]])
  }

  # Extract CCTV
  if (!is.na(cctv_col)) {
    df$cctv <- grepl("yes|y|1|true|cctv|camera", tolower(trimws(df[[cctv_col]])))
  }

  # Extract status
  if (!is.na(status_col)) {
    df$cleared <- grepl("cleared|solved|yes|y|1|true", tolower(trimws(df[[status_col]])))
  }

  return(df)
}

load_homicide_data <- function() {
  csv_path <- "data/homicides.csv"

  # First attempt: load from local cached CSV.
  if (file.exists(csv_path)) {
    message("Loading homicide data from local cache: ", csv_path)
    cached <- tryCatch(read.csv(csv_path, stringsAsFactors = FALSE), error = function(e) {
      message("Failed to read cache: ", e$message)
      NULL
    })

    if (!is.null(cached) && nrow(cached) > 0) {
      cached$year <- as.factor(cached$year)
      return(cached)
    }
  }

  # Fallback: scrape from remote URLs.
  urls <- list(
    "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
    "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
    "2023" = "https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html"
  )

  all_data <- list()
  for (year in names(urls)) {
    data <- scrape_homicide_data(urls[[year]], year)
    if (!is.null(data)) {
      all_data[[year]] <- data
    }
  }

  if (length(all_data) == 0) {
    warning("No data could be scraped; returning empty data frame. Check network or source pages.")
    return(tibble(year = factor(), date = as.Date(character()), age = numeric(), method = character(), location = character(), cctv = logical(), cleared = logical(), month = integer(), month_name = factor()))
  }

  df <- bind_rows(all_data)
  df <- clean_homicide_data(df)

  df <- df %>%
    filter(!is.na(age) & age > 0 & age < 120) %>%
    mutate(year = as.factor(year))

  # write cache for faster subsequent startups
  dir.create(dirname(csv_path), recursive = TRUE, showWarnings = FALSE)
  tryCatch(
    write.csv(df, csv_path, row.names = FALSE),
    error = function(e) message("Failed to save cache: ", e$message)
  )

  df
}

# UI
ui <- dashboardPage(
  dashboardHeader(title = "Baltimore Homicide Analysis Dashboard"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("dashboard")),
      menuItem("Trends", tabName = "trends", icon = icon("line-chart")),
      menuItem("Demographics", tabName = "demographics", icon = icon("users")),
      menuItem("Methods", tabName = "methods", icon = icon("crosshairs")),
      menuItem("Data Table", tabName = "data", icon = icon("table"))
    ),
    hr(),
    selectInput("year_filter", "Select Years:",
                choices = c("2023", "2024", "2025"),
                selected = c("2023", "2024", "2025"),
                multiple = TRUE),
    sliderInput("age_filter", "Age Range:",
                min = 0, max = 120, value = c(0, 120)),
    checkboxGroupInput("method_filter", "Methods:",
                       choices = NULL),  # Will be updated dynamically
    dateRangeInput("date_filter", "Date Range:",
                   start = "2023-01-01", end = "2025-12-31")
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "overview",
              fluidRow(
                valueBoxOutput("total_homicides"),
                valueBoxOutput("clearance_rate"),
                valueBoxOutput("avg_age"),
                valueBoxOutput("cctv_percentage")
              ),
              fluidRow(
                box(plotlyOutput("homicides_over_time"), width = 12)
              )
      ),
      tabItem(tabName = "trends",
              fluidRow(
                box(plotlyOutput("monthly_trends"), width = 12)
              ),
              fluidRow(
                box(plotlyOutput("yearly_comparison"), width = 6),
                box(plotlyOutput("clearance_trends"), width = 6)
              )
      ),
      tabItem(tabName = "demographics",
              fluidRow(
                box(plotlyOutput("age_histogram"), width = 12)
              ),
              fluidRow(
                box(plotlyOutput("age_by_year"), width = 6),
                box(plotlyOutput("age_by_method"), width = 6)
              )
      ),
      tabItem(tabName = "methods",
              fluidRow(
                box(plotlyOutput("method_distribution"), width = 12)
              ),
              fluidRow(
                box(plotlyOutput("method_by_year"), width = 6),
                box(plotlyOutput("method_clearance"), width = 6)
              )
      ),
      tabItem(tabName = "data",
              fluidRow(
                box(DTOutput("homicide_table"), width = 12)
              )
      )
    )
  )
)

# Server
server <- function(input, output, session) {
  # Load once into reactiveVal, avoid repeated remote scraping.
  homicide_data <- reactiveVal(load_homicide_data())

  # Update method choices based on data
  observe({
    data <- homicide_data()
    methods <- unique(data$method)
    methods <- methods[!is.na(methods)]
    updateCheckboxGroupInput(session, "method_filter",
                             choices = methods,
                             selected = methods)
  })

  # Filtered data
  filtered_data <- reactive({
    data <- homicide_data()
    if (nrow(data) == 0) {
      return(data)
    }

    # Apply filters
    data <- data %>%
      filter(year %in% input$year_filter,
             age >= input$age_filter[1],
             age <= input$age_filter[2])

    if (!is.null(input$method_filter) && length(input$method_filter) > 0) {
      data <- data %>% filter(method %in% input$method_filter)
    }

    if (!is.null(input$date_filter) && !is.na(input$date_filter[1]) && !is.na(input$date_filter[2])) {
      data <- data %>%
        filter(!is.na(date) & date >= input$date_filter[1] & date <= input$date_filter[2])
    }

    data
  })

  # Summary statistics
  output$total_homicides <- renderValueBox({
    req(nrow(filtered_data()) > 0)
    valueBox(
      nrow(filtered_data()),
      "Total Homicides",
      icon = icon("skull-crossbones"),
      color = "red"
    )
  })

  output$clearance_rate <- renderValueBox({
    req(nrow(filtered_data()) > 0)
    rate <- mean(filtered_data()$cleared, na.rm = TRUE) * 100
    valueBox(
      paste0(round(rate, 1), "%"),
      "Clearance Rate",
      icon = icon("check-circle"),
      color = "green"
    )
  })

  output$avg_age <- renderValueBox({
    req(nrow(filtered_data()) > 0)
    avg <- mean(filtered_data()$age, na.rm = TRUE)
    valueBox(
      round(avg, 1),
      "Average Victim Age",
      icon = icon("user"),
      color = "blue"
    )
  })

  output$cctv_percentage <- renderValueBox({
    req(nrow(filtered_data()) > 0)
    pct <- mean(filtered_data()$cctv, na.rm = TRUE) * 100
    valueBox(
      paste0(round(pct, 1), "%"),
      "Incidents with CCTV",
      icon = icon("video"),
      color = "purple"
    )
  })

  # Plots
  output$homicides_over_time <- renderPlotly({
    data <- filtered_data() %>%
      group_by(year, month) %>%
      summarise(count = n(), .groups = 'drop') %>%
      mutate(date = as.Date(paste(year, month, "01", sep = "-")))

    plot_ly(data, x = ~date, y = ~count, type = 'scatter', mode = 'lines+markers') %>%
      layout(title = "Homicides Over Time",
             xaxis = list(title = "Date"),
             yaxis = list(title = "Number of Homicides"))
  })

  output$monthly_trends <- renderPlotly({
    data <- filtered_data() %>%
      group_by(month_name) %>%
      summarise(count = n(), .groups = 'drop') %>%
      mutate(month_name = factor(month_name, levels = month.abb))

    plot_ly(data, x = ~month_name, y = ~count, type = 'bar') %>%
      layout(title = "Monthly Homicide Trends",
             xaxis = list(title = "Month"),
             yaxis = list(title = "Number of Homicides"))
  })

  output$yearly_comparison <- renderPlotly({
    data <- filtered_data() %>%
      group_by(year) %>%
      summarise(count = n(), .groups = 'drop')

    plot_ly(data, x = ~year, y = ~count, type = 'bar') %>%
      layout(title = "Homicides by Year",
             xaxis = list(title = "Year"),
             yaxis = list(title = "Number of Homicides"))
  })

  output$clearance_trends <- renderPlotly({
    data <- filtered_data() %>%
      group_by(year) %>%
      summarise(clearance_rate = mean(cleared, na.rm = TRUE) * 100, .groups = 'drop')

    plot_ly(data, x = ~year, y = ~clearance_rate, type = 'scatter', mode = 'lines+markers') %>%
      layout(title = "Clearance Rate Trends",
             xaxis = list(title = "Year"),
             yaxis = list(title = "Clearance Rate (%)"))
  })

  output$age_histogram <- renderPlotly({
    p <- ggplot(filtered_data(), aes(x = age)) +
      geom_histogram(binwidth = 5, fill = "#d62728", color = "black", alpha = 0.7) +
      labs(title = "Victim Age Distribution",
           x = "Age",
           y = "Count")

    ggplotly(p)
  })

  output$age_by_year <- renderPlotly({
    data <- filtered_data() %>%
      group_by(year) %>%
      summarise(avg_age = mean(age, na.rm = TRUE), .groups = 'drop')

    plot_ly(data, x = ~year, y = ~avg_age, type = 'bar') %>%
      layout(title = "Average Victim Age by Year",
             xaxis = list(title = "Year"),
             yaxis = list(title = "Average Age"))
  })

  output$age_by_method <- renderPlotly({
    data <- filtered_data() %>%
      group_by(method) %>%
      summarise(avg_age = mean(age, na.rm = TRUE), .groups = 'drop')

    plot_ly(data, x = ~method, y = ~avg_age, type = 'bar') %>%
      layout(title = "Average Victim Age by Method",
             xaxis = list(title = "Method"),
             yaxis = list(title = "Average Age"))
  })

  output$method_distribution <- renderPlotly({
    data <- filtered_data() %>%
      group_by(method) %>%
      summarise(count = n(), .groups = 'drop')

    plot_ly(data, labels = ~method, values = ~count, type = 'pie') %>%
      layout(title = "Homicide Methods Distribution")
  })

  output$method_by_year <- renderPlotly({
    data <- filtered_data() %>%
      group_by(year, method) %>%
      summarise(count = n(), .groups = 'drop')

    plot_ly(data, x = ~year, y = ~count, color = ~method, type = 'bar') %>%
      layout(title = "Methods by Year",
             xaxis = list(title = "Year"),
             yaxis = list(title = "Count"),
             barmode = 'stack')
  })

  output$method_clearance <- renderPlotly({
    data <- filtered_data() %>%
      group_by(method) %>%
      summarise(clearance_rate = mean(cleared, na.rm = TRUE) * 100, .groups = 'drop')

    plot_ly(data, x = ~method, y = ~clearance_rate, type = 'bar') %>%
      layout(title = "Clearance Rate by Method",
             xaxis = list(title = "Method"),
             yaxis = list(title = "Clearance Rate (%)"))
  })

  output$homicide_table <- renderDT({
    datatable(filtered_data() %>%
                select(year, date, age, method, location, cctv, cleared) %>%
                arrange(desc(date)))
  })
}

# Run the app
shinyApp(ui = ui, server = server)