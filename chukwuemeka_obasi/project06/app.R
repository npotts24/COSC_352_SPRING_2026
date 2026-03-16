library(shiny)
library(plotly)
library(dplyr)
library(leaflet)
library(lubridate)
library(rvest)
library(stringr)

# -----------------------------
# Scrape and Parse the homicide data
# -----------------------------
url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

# Scrape the table from the blog
webpage <- read_html(url)
raw_table <- webpage %>% 
  html_nodes("table") %>% 
  html_table(fill = TRUE) %>% 
  .[[1]]

# --- Data Cleaning ---
data <- raw_table %>%
  filter(!grepl("Victim", X1)) %>%
  select(name_age = X1, date = X2, address = X3, method = X4, cctv = X5, cleared = X6)

# Extract Age and Dates
data$victim_age <- as.numeric(str_extract(data$name_age, "\\d+"))
data$date <- mdy(data$date)
data$year <- year(data$date)
data$month <- month(data$date, label = TRUE)

# Clean Logical Columns
data$cctv <- grepl("Yes", data$cctv, ignore.case = TRUE)
data$cleared <- grepl("Yes", data$cleared, ignore.case = TRUE)

# Placeholder Coordinates for the map
data$latitude <- 39.2904
data$longitude <- -76.6122

# Console Output (Required by your assignment)
print("--- Scraped Data Preview ---")
print(head(data))

# -----------------------------
# User Interface
# -----------------------------
ui <- fluidPage(
  titlePanel("Baltimore Police Homicide Dashboard"),
  sidebarLayout(
    sidebarPanel(
      selectInput("year", "Select Year", 
                  choices = sort(unique(data$year), na.last = TRUE), 
                  selected = max(data$year, na.rm = TRUE)),
      sliderInput("age", "Victim Age Range", 
                  min = min(data$victim_age, na.rm = TRUE), 
                  max = max(data$victim_age, na.rm = TRUE), 
                  value = c(18, 60)),
      checkboxGroupInput("method", "Homicide Method", 
                         choices = unique(data$method), 
                         selected = unique(data$method))
    ),
    mainPanel(
      h3("Summary Statistics"),
      fluidRow(
        column(3, h4("Total"), textOutput("total_homicides")),
        column(3, h4("Clearance"), textOutput("clearance_rate")),
        column(3, h4("Avg Age"), textOutput("avg_age")),
        column(3, h4("CCTV %"), textOutput("cctv_percent"))
      ),
      hr(),
      tabsetPanel(
        tabPanel("Monthly Trend", plotlyOutput("trend_plot")),
        tabPanel("Method Distribution", plotlyOutput("method_plot")),
        tabPanel("Map", leafletOutput("map"))
      )
    )
  )
)

# -----------------------------
# Server
# -----------------------------
server <- function(input, output) {
  filtered_data <- reactive({
    data %>%
      filter(year == input$year,
             victim_age >= input$age[1],
             victim_age <= input$age[2],
             method %in% input$method)
  })

  output$total_homicides <- renderText({ nrow(filtered_data()) })
  output$clearance_rate <- renderText({
    df <- filtered_data()
    if(nrow(df) == 0) return("0%")
    paste0(round(mean(df$cleared, na.rm = TRUE) * 100, 2), "%")
  })
  output$avg_age <- renderText({ round(mean(filtered_data()$victim_age, na.rm = TRUE), 1) })
  output$cctv_percent <- renderText({
    df <- filtered_data()
    if(nrow(df) == 0) return("0%")
    paste0(round(mean(df$cctv, na.rm = TRUE) * 100, 2), "%")
  })
  output$trend_plot <- renderPlotly({
    df <- filtered_data() %>% group_by(month) %>% summarise(count = n())
    plot_ly(df, x = ~month, y = ~count, type = "scatter", mode = "lines+markers")
  })
  output$method_plot <- renderPlotly({
    df <- filtered_data() %>% group_by(method) %>% summarise(count = n())
    plot_ly(df, x = ~method, y = ~count, type = "bar")
  })
  output$map <- renderLeaflet({
    leaflet(filtered_data()) %>% addTiles() %>%
      addCircleMarkers(lng = ~longitude, lat = ~latitude, radius = 4, popup = ~method)
  })
}

shinyApp(ui = ui, server = server)