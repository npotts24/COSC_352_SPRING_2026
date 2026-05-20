library(shiny)
library(plotly)
library(DT)
library(dplyr)
library(lubridate)

source("scrape.R")  # Load data

ui <- fluidPage(
  titlePanel("Baltimore City Homicide Analysis Dashboard"),
  sidebarLayout(
    sidebarPanel(
      selectInput("year", "Select Year:", choices = c("All", unique(homicide_data$year)), selected = "All"),
      sliderInput("ageRange", "Age Range:", min = 0, max = 100, value = c(0, 100))
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Summary",
                 h3("Key Statistics"),
                 textOutput("totalHomicides"),
                 textOutput("avgAge"),
                 textOutput("mostCommonMethod")
        ),
        tabPanel("Visualizations",
                 plotlyOutput("monthlyChart"),
                 plotlyOutput("methodChart")
        ),
        tabPanel("Data Table",
                 DTOutput("dataTable")
        )
      )
    )
  )
)

server <- function(input, output) {
  filteredData <- reactive({
    data <- homicide_data
    if (input$year != "All") {
      data <- data %>% filter(year == as.integer(input$year))
    }
    data <- data %>% filter(age >= input$ageRange[1] & age <= input$ageRange[2] | is.na(age))
    data
  })

  output$totalHomicides <- renderText({
    paste("Total Homicides:", nrow(filteredData()))
  })

  output$avgAge <- renderText({
    avg <- mean(filteredData()$age, na.rm = TRUE)
    paste("Average Age:", round(avg, 1))
  })

  output$mostCommonMethod <- renderText({
    method <- filteredData() %>% count(method) %>% arrange(desc(n)) %>% slice(1) %>% pull(method)
    paste("Most Common Method:", method)
  })

  output$monthlyChart <- renderPlotly({
    data <- filteredData()
    if (nrow(data) == 0) return(plotly_empty())
    monthly <- data %>%
      mutate(month = floor_date(date, "month")) %>%
      count(month)
    plot_ly(monthly, x = ~month, y = ~n, type = 'scatter', mode = 'lines+markers') %>%
      layout(title = "Homicides per Month", xaxis = list(title = "Month"), yaxis = list(title = "Count"))
  })

  output$methodChart <- renderPlotly({
    data <- filteredData()
    if (nrow(data) == 0) return(plotly_empty())
    method_count <- data %>% count(method)
    plot_ly(method_count, x = ~method, y = ~n, type = 'bar') %>%
      layout(title = "Homicides by Method", xaxis = list(title = "Method"), yaxis = list(title = "Count"))
  })

  output$dataTable <- renderDT({
    datatable(filteredData())
  })
}

shinyApp(ui = ui, server = server)