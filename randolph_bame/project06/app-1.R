
library(shiny)
library(shinydashboard)
library(dplyr)
library(plotly)
library(lubridate)

data <- read.csv("homicide_data.csv")
data$date <- as.Date(data$date)

ui <- dashboardPage(

 dashboardHeader(title = "Baltimore Homicide Dashboard"),

 dashboardSidebar(

  sliderInput("year",
   "Year range",
   min = year(min(data$date)),
   max = year(max(data$date)),
   value = c(year(min(data$date)), year(max(data$date)))
  ),

  sliderInput("age",
   "Victim age",
   min = min(data$age),
   max = max(data$age),
   value = c(18,60)
  )

 ),

 dashboardBody(

  fluidRow(
   valueBoxOutput("total"),
   valueBoxOutput("clearance"),
   valueBoxOutput("average_age")
  ),

  fluidRow(
   box(plotlyOutput("month_plot"), width = 6),
   box(plotlyOutput("method_plot"), width = 6)
  )

 )

)

server <- function(input, output) {

 filtered_data <- reactive({

  data %>%
   filter(
    year(date) >= input$year[1],
    year(date) <= input$year[2],
    age >= input$age[1],
    age <= input$age[2]
   )

 })

 output$total <- renderValueBox({

  valueBox(
   nrow(filtered_data()),
   "Total homicides"
  )

 })

 output$clearance <- renderValueBox({

  rate <- mean(filtered_data()$cleared == "Yes") * 100

  valueBox(
   paste0(round(rate,1), " percent"),
   "Clearance rate"
  )

 })

 output$average_age <- renderValueBox({

  valueBox(
   round(mean(filtered_data()$age),1),
   "Average victim age"
  )

 })

 output$month_plot <- renderPlotly({

  df <- filtered_data() %>%
   mutate(month = floor_date(date, "month")) %>%
   count(month)

  plot_ly(df, x = ~month, y = ~n, type = "scatter", mode = "lines")

 })

 output$method_plot <- renderPlotly({

  df <- filtered_data() %>%
   count(method)

  plot_ly(df, x = ~method, y = ~n, type = "bar")

 })

}

shinyApp(ui, server)
