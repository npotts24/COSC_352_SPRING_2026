library(shiny)
library(shinydashboard)
library(plotly)
library(dplyr)
library(leaflet)
library(DT)
library(jsonlite)
library(lubridate)


# ---- DATA PIPELINE ----
url <- "https://raw.githubusercontent.com/washingtonpost/data-homicides/master/homicide-data.csv"
homicides <- read.csv(url, stringsAsFactors = FALSE)


homicides <- homicides %>%
  mutate(
    reported_date = ymd(reported_date),
    year = year(reported_date),
    month = month(reported_date, label = TRUE),
    victim_age = as.numeric(victim_age)
  ) %>%
  filter(city == "Baltimore")


# ---- UI ----
ui <- dashboardPage(
 
  dashboardHeader(title = "Baltimore Police Department Homicide Dashboard"),
 
  dashboardSidebar(
   
    selectInput(
      "year",
      "Select Year:",
      choices = sort(unique(homicides$year)),
      selected = max(homicides$year)
    ),
   
    sliderInput(
      "age",
      "Victim Age Range:",
      min = 0,
      max = 100,
      value = c(18,60)
    ),
   
    checkboxGroupInput(
      "method",
      "Method:",
      choices = unique(homicides$method),
      selected = unique(homicides$method)
    )
   
  ),
 
  dashboardBody(
   
    fluidRow(
      valueBoxOutput("totalHomicides"),
      valueBoxOutput("clearanceRate"),
      valueBoxOutput("avgAge")
    ),
   
    tabBox(
      width = 12,
     
      tabPanel(
        "Monthly Trends",
        plotlyOutput("trendPlot")
      ),
     
      tabPanel(
        "Method Breakdown",
        plotlyOutput("methodPlot")
      ),
     
      tabPanel(
        "Data Table",
        DTOutput("table")
      )
     
    )
   
  )
)


# ---- SERVER ----
server <- function(input, output, session){


  filtered <- reactive({


    df <- homicides %>%
      filter(
        year == input$year,
        !is.na(victim_age),
        victim_age >= input$age[1],
        victim_age <= input$age[2]
      )


    if(!is.null(input$method)){
      df <- df %>% filter(method %in% input$method)
    }


    df


  })


  # ---- SUMMARY STATS ----
  output$totalHomicides <- renderValueBox({
   
    valueBox(
      value = nrow(filtered()),
      subtitle = "Total Homicides",
      color = "red"
    )
   
  })


  output$clearanceRate <- renderValueBox({
   
    rate <- mean(filtered()$disposition == "Closed by arrest", na.rm = TRUE) * 100
   
    valueBox(
      value = paste0(round(rate,1), "%"),
      subtitle = "Clearance Rate",
      color = "green"
    )
   
  })


  output$avgAge <- renderValueBox({
   
    valueBox(
      value = round(mean(filtered()$victim_age, na.rm = TRUE),1),
      subtitle = "Average Victim Age",
      color = "blue"
    )
   
  })


  # ---- MONTHLY TREND ----
  output$trendPlot <- renderPlotly({
   
    df <- filtered() %>%
      group_by(month) %>%
      summarise(count = n(), .groups = "drop")
   
    plot_ly(
      df,
      x = ~month,
      y = ~count,
      type = "scatter",
      mode = "lines+markers"
    ) %>%
      layout(title = "Monthly Homicide Trend")
   
  })


  # ---- METHOD BREAKDOWN ----
  output$methodPlot <- renderPlotly({
   
    df <- filtered() %>%
      group_by(method) %>%
      summarise(count = n(), .groups = "drop")
   
    plot_ly(
      df,
      x = ~method,
      y = ~count,
      type = "bar"
    ) %>%
      layout(title = "Homicides by Method")
   
  })


  # ---- DATA TABLE ----
  output$table <- renderDT({
   
    datatable(filtered())
   
  })


}


shinyApp(ui, server)
