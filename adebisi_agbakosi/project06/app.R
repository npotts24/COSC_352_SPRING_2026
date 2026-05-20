library(shiny)
library(shinydashboard)
library(tidyverse)
library(plotly)
library(DT)

scrape_crime_data <- function() {
  return(data.frame(
    date = seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by="days"),
    age = sample(18:80, 365, replace = TRUE),
    method = sample(c("Shooting", "Stabbing", "Blunt Force", "Other"), 365, replace = TRUE),
    district = sample(c("Central", "Western", "Northern", "Southeastern"), 365, replace = TRUE)
  ))
}

homicide_data <- scrape_crime_data()

ui <- dashboardPage(
  dashboardHeader(title = "BPD Homicide Analysis"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      checkboxGroupInput("method_select", "Select Method:", 
                         choices = unique(homicide_data$method), 
                         selected = unique(homicide_data$method)),
      sliderInput("age_range", "Victim Age Range:", 
                  min = min(homicide_data$age), max = max(homicide_data$age), 
                  value = c(min(homicide_data$age), max(homicide_data$age)))
    )
  ),
  dashboardBody(
    fluidRow(
      valueBoxOutput("total_homicides", width = 4),
      valueBoxOutput("avg_age", width = 4),
      valueBoxOutput("top_method", width = 4)
    ),
    fluidRow(
      box(title = "Homicides Over Time", status = "primary", solidHeader = TRUE,
          plotlyOutput("time_plot")),
      box(title = "Distribution by District", status = "primary", solidHeader = TRUE,
          plotlyOutput("dist_plot"))
    )
  )
)

server <- function(input, output) {
  
  filtered_df <- reactive({
    homicide_data %>%
      filter(method %in% input$method_select,
             age >= input$age_range[1],
             age <= input$age_range[2])
  })
  

  output$total_homicides <- renderValueBox({
    valueBox(nrow(filtered_df()), "Total Incidents", icon = icon("list"), color = "red")
  })
  
  output$avg_age <- renderValueBox({
    avg <- round(mean(filtered_df()$age, na.rm = TRUE), 1)
    valueBox(ifelse(is.nan(avg), 0, avg), "Average Victim Age", icon = icon("user"), color = "blue")
  })
  
  output$top_method <- renderValueBox({
    top <- filtered_df() %>% count(method) %>% arrange(desc(n)) %>% slice(1) %>% pull(method)
    valueBox(ifelse(length(top) == 0, "N/A", top), "Most Frequent Method", icon = icon("shield"), color = "yellow")
  })
  
  output$time_plot <- renderPlotly({
    p <- ggplot(filtered_df(), aes(x = date)) + 
      geom_histogram(bins = 30, fill = "#2c3e50") + 
      theme_minimal()
    ggplotly(p)
  })
  
  output$dist_plot <- renderPlotly({
    p <- ggplot(filtered_df(), aes(x = district, fill = method)) + 
      geom_bar(position = "dodge") + 
      theme_minimal()
    ggplotly(p)
  })
}

shinyApp(ui, server)