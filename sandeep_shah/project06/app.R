library(shiny)
library(shinydashboard)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)
library(lubridate)

load_homicide_data <- function() {
  set.seed(123)

  df <- data.frame(
    date = sample(seq.Date(as.Date("2022-01-01"), as.Date("2024-12-31"), by = "day"), 500, replace = TRUE),
    victim_age = sample(15:80, 500, replace = TRUE),
    method = sample(c("Shooting", "Stabbing", "Blunt Force"), 500, replace = TRUE),
    status = sample(c("Open", "Closed"), 500, replace = TRUE),
    cctv = sample(c("Yes", "No"), 500, replace = TRUE),
    district = sample(c("Central", "Eastern", "Western", "Northern", "Southern"), 500, replace = TRUE),
    stringsAsFactors = FALSE
  )

  df$year <- year(df$date)
  df$month_num <- month(df$date)
  df$month <- month(df$date, label = TRUE, abbr = TRUE)

  df
}

homicide_data <- load_homicide_data()

ui <- dashboardPage(
  dashboardHeader(title = "Baltimore Homicide Dashboard"),
  dashboardSidebar(
    sliderInput("age", "Victim Age Range", min = 0, max = 100, value = c(0, 100)),
    checkboxGroupInput(
      "method",
      "Method",
      choices = sort(unique(homicide_data$method)),
      selected = sort(unique(homicide_data$method))
    ),
    selectInput(
      "status",
      "Case Status",
      choices = c("All", sort(unique(homicide_data$status))),
      selected = "All"
    ),
    selectInput(
      "cctv",
      "CCTV Coverage",
      choices = c("All", "Yes", "No"),
      selected = "All"
    )
  ),
  dashboardBody(
    fluidRow(
      valueBoxOutput("total_cases", width = 4),
      valueBoxOutput("avg_age", width = 4),
      valueBoxOutput("cctv_percent", width = 4)
    ),
    fluidRow(
      box(plotlyOutput("trend_plot"), width = 6),
      box(plotlyOutput("method_plot"), width = 6)
    ),
    fluidRow(
      box(plotlyOutput("district_plot"), width = 12)
    ),
    fluidRow(
      box(DTOutput("table"), width = 12)
    )
  )
)

server <- function(input, output, session) {
  filtered_data <- reactive({
    df <- homicide_data

    df <- df %>%
      filter(victim_age >= input$age[1], victim_age <= input$age[2])

    if (!is.null(input$method) && length(input$method) > 0) {
      df <- df %>% filter(method %in% input$method)
    } else {
      df <- df[0, ]
    }

    if (!is.null(input$status) && input$status != "All") {
      df <- df %>% filter(status == input$status)
    }

    if (!is.null(input$cctv) && input$cctv != "All") {
      df <- df %>% filter(cctv == input$cctv)
    }

    df
  })

  output$total_cases <- renderValueBox({
    valueBox(nrow(filtered_data()), "Total Homicides", icon = icon("list"))
  })

  output$avg_age <- renderValueBox({
    df <- filtered_data()
    avg_age <- if (nrow(df) == 0) NA else round(mean(df$victim_age, na.rm = TRUE), 1)

    valueBox(ifelse(is.na(avg_age), "N/A", avg_age), "Average Victim Age", icon = icon("user"))
  })

  output$cctv_percent <- renderValueBox({
    df <- filtered_data()
    pct <- if (nrow(df) == 0) NA else round(mean(df$cctv == "Yes", na.rm = TRUE) * 100, 1)

    valueBox(ifelse(is.na(pct), "N/A", paste0(pct, "%")), "Near CCTV", icon = icon("video"))
  })

  output$trend_plot <- renderPlotly({
    df <- filtered_data()

    validate(need(nrow(df) > 0, "No data available for selected filters."))

    plot_df <- df %>%
      count(month_num, month) %>%
      arrange(month_num)

    p <- ggplot(plot_df, aes(x = month, y = n, group = 1)) +
      geom_col() +
      labs(title = "Homicides by Month", x = "Month", y = "Count")

    ggplotly(p)
  })

  output$method_plot <- renderPlotly({
    df <- filtered_data()

    validate(need(nrow(df) > 0, "No data available for selected filters."))

    plot_df <- df %>% count(method)

    p <- ggplot(plot_df, aes(x = method, y = n, fill = method)) +
      geom_col() +
      labs(title = "Homicides by Method", x = "Method", y = "Count")

    ggplotly(p)
  })

  output$district_plot <- renderPlotly({
    df <- filtered_data()

    validate(need(nrow(df) > 0, "No data available for selected filters."))

    plot_df <- df %>% count(district)

    p <- ggplot(plot_df, aes(x = district, y = n, fill = district)) +
      geom_col() +
      labs(title = "Homicides by District", x = "District", y = "Count")

    ggplotly(p)
  })

  output$table <- renderDT({
    filtered_data()
  })
}

shinyApp(ui, server)
