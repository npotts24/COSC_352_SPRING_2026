library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(rvest)
library(dplyr)
library(stringr)
library(lubridate)
library(tidyr)
library(ggplot2)

YEAR_URLS <- list(
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
)

safe_read_html <- function(url) {
  tryCatch(
    read_html(url),
    error = function(e) stop(paste("Failed to download:", url))
  )
}

normalize_names <- function(nms) {
  nms %>%
    str_replace_all("\\s+", " ") %>%
    str_trim() %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_replace_all("_+", "_") %>%
    str_replace_all("^_|_$", "")
}

extract_homicide_table <- function(doc) {
  tables <- html_elements(doc, "table")
  if (length(tables) == 0) stop("No HTML tables found on the page.")
  df <- tables[[1]] %>% html_table(fill = TRUE)
  names(df) <- normalize_names(names(df))
  df <- df %>% select(where(~ !all(is.na(.x) | str_trim(as.character(.x)) == "")))
  df
}

detect_date_col <- function(df) {
  nms <- names(df)
  hit <- nms[str_detect(nms, "date")]
  if (length(hit) > 0) return(hit[1])

  date_regex <- "^\\d{2}/\\d{2}/\\d{2}$"
  scores <- sapply(nms, function(col) {
    vals <- str_squish(as.character(df[[col]]))
    mean(str_detect(vals, date_regex), na.rm = TRUE)
  })

  best <- nms[which.max(scores)]
  if (length(best) == 0 || is.na(scores[best]) || scores[best] < 0.05) {
    stop("Could not detect date column.")
  }
  best
}

find_col <- function(df, patterns) {
  nms <- names(df)
  for (p in patterns) {
    hit <- nms[str_detect(nms, p)]
    if (length(hit) > 0) return(hit[1])
  }
  NA_character_
}

clean_df <- function(df, yr) {
  df <- df %>% mutate(across(everything(), ~ as.character(.x)))
  date_col <- detect_date_col(df)

  age_col <- find_col(df, c("^age$", "age"))
  method_col <- find_col(df, c("cause", "method", "weapon", "means"))
  status_col <- find_col(df, c("status", "closed", "case"))
  cctv_col <- find_col(df, c("cctv", "camera"))
  location_col <- find_col(df, c("location", "address", "block"))

  out <- df %>%
    mutate(date_raw = str_squish(.data[[date_col]])) %>%
    filter(str_detect(date_raw, "^\\d{2}/\\d{2}/\\d{2}$")) %>%
    mutate(
      year = as.integer(yr),
      date = mdy(date_raw),
      month = month(date, label = TRUE, abbr = TRUE),
      month_num = month(date)
    ) %>%
    filter(!is.na(date))

  out$age <- if (!is.na(age_col)) suppressWarnings(as.integer(str_extract(out[[age_col]], "\\d+"))) else NA_integer_
  out$method <- if (!is.na(method_col)) str_squish(out[[method_col]]) else "Unknown"
  out$case_status <- if (!is.na(status_col)) str_squish(out[[status_col]]) else "Unknown"
  out$cctv <- if (!is.na(cctv_col)) str_squish(out[[cctv_col]]) else "Unknown"
  out$location <- if (!is.na(location_col)) str_squish(out[[location_col]]) else "Unknown"

  out$method[out$method == ""] <- "Unknown"
  out$case_status[out$case_status == ""] <- "Unknown"
  out$cctv[out$cctv == ""] <- "Unknown"
  out$location[out$location == ""] <- "Unknown"

  out
}

load_data <- function() {
  rows <- list()
  for (yr in names(YEAR_URLS)) {
    doc <- safe_read_html(YEAR_URLS[[yr]])
    raw <- extract_homicide_table(doc)
    rows[[yr]] <- clean_df(raw, yr)
  }
  bind_rows(rows)
}

homicide_data <- load_data()

max_age_value <- suppressWarnings(max(homicide_data$age, na.rm = TRUE))
if (!is.finite(max_age_value)) max_age_value <- 100

ui <- dashboardPage(
  dashboardHeader(title = "Baltimore Homicide Dashboard"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("chart-line")),
      selectInput(
        "year_filter", "Year(s)",
        choices = sort(unique(homicide_data$year)),
        selected = sort(unique(homicide_data$year)),
        multiple = TRUE
      ),
      sliderInput(
        "age_filter", "Victim Age Range",
        min = 0, max = max_age_value, value = c(0, max_age_value)
      ),
      selectInput(
        "method_filter", "Method",
        choices = sort(unique(homicide_data$method)),
        selected = sort(unique(homicide_data$method)),
        multiple = TRUE
      ),
      selectInput(
        "status_filter", "Case Status",
        choices = sort(unique(homicide_data$case_status)),
        selected = sort(unique(homicide_data$case_status)),
        multiple = TRUE
      ),
      selectInput(
        "cctv_filter", "CCTV Nearby",
        choices = sort(unique(homicide_data$cctv)),
        selected = sort(unique(homicide_data$cctv)),
        multiple = TRUE
      )
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "dashboard",
        fluidRow(
          valueBoxOutput("total_box", width = 3),
          valueBoxOutput("clearance_box", width = 3),
          valueBoxOutput("avg_age_box", width = 3),
          valueBoxOutput("cctv_box", width = 3)
        ),
        fluidRow(
          box(plotlyOutput("monthly_plot"), width = 6, title = "Homicides by Month"),
          box(plotlyOutput("method_plot"), width = 6, title = "Method Breakdown")
        ),
        fluidRow(
          box(DTOutput("data_table"), width = 12, title = "Filtered Incident Data")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  filtered_data <- reactive({
    df <- homicide_data

    if (length(input$year_filter) > 0) {
      df <- df %>% filter(year %in% input$year_filter)
    } else {
      df <- df[0, ]
    }

    if ("age" %in% names(df)) {
      df <- df %>% filter(is.na(age) | (age >= input$age_filter[1] & age <= input$age_filter[2]))
    }

    if (length(input$method_filter) > 0) {
      df <- df %>% filter(method %in% input$method_filter)
    } else {
      df <- df[0, ]
    }

    if (length(input$status_filter) > 0) {
      df <- df %>% filter(case_status %in% input$status_filter)
    } else {
      df <- df[0, ]
    }

    if (length(input$cctv_filter) > 0) {
      df <- df %>% filter(cctv %in% input$cctv_filter)
    } else {
      df <- df[0, ]
    }

    df
  })

  output$total_box <- renderValueBox({
    df <- filtered_data()
    valueBox(nrow(df), "Filtered Homicides", icon = icon("list"), color = "red")
  })

  output$clearance_box <- renderValueBox({
    df <- filtered_data()
    if (nrow(df) == 0) {
      rate <- "0%"
    } else {
      closed_hits <- str_detect(str_to_lower(df$case_status), "closed|cleared")
      rate <- paste0(round(mean(closed_hits, na.rm = TRUE) * 100, 1), "%")
    }
    valueBox(rate, "Estimated Clearance Rate", icon = icon("check"), color = "green")
  })

  output$avg_age_box <- renderValueBox({
    df <- filtered_data()
    avg_age <- if (nrow(df) == 0 || all(is.na(df$age))) "N/A" else round(mean(df$age, na.rm = TRUE), 1)
    valueBox(avg_age, "Average Victim Age", icon = icon("user"), color = "yellow")
  })

  output$cctv_box <- renderValueBox({
    df <- filtered_data()
    if (nrow(df) == 0) {
      pct <- "0%"
    } else {
      cam_hits <- str_detect(str_to_lower(df$cctv), "yes|y|near|camera")
      pct <- paste0(round(mean(cam_hits, na.rm = TRUE) * 100, 1), "%")
    }
    valueBox(pct, "Incidents Near CCTV", icon = icon("video"), color = "blue")
  })

  output$monthly_plot <- renderPlotly({
    df <- filtered_data()
    validate(need(nrow(df) > 0, "No data matches the selected filters."))

    m <- df %>%
      count(year, month_num, month, name = "homicides") %>%
      arrange(year, month_num)

    p <- ggplot(m, aes(x = month, y = homicides, color = factor(year), group = year)) +
      geom_line() +
      geom_point() +
      labs(x = "Month", y = "Homicides", color = "Year") +
      theme_minimal()

    ggplotly(p)
  })

  output$method_plot <- renderPlotly({
    df <- filtered_data()
    validate(need(nrow(df) > 0, "No data matches the selected filters."))

    m <- df %>%
      count(method, name = "count") %>%
      arrange(desc(count)) %>%
      slice_head(n = 10)

    p <- ggplot(m, aes(x = reorder(method, count), y = count)) +
      geom_col() +
      coord_flip() +
      labs(x = "Method", y = "Count") +
      theme_minimal()

    ggplotly(p)
  })

  output$data_table <- renderDT({
    df <- filtered_data() %>%
      select(any_of(c("year", "date", "age", "method", "case_status", "cctv", "location")))
    datatable(df, options = list(pageLength = 10, scrollX = TRUE))
  })
}

shinyApp(ui, server)
