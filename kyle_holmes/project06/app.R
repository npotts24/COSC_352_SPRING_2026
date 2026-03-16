library(shiny)
library(shinydashboard)
library(plotly)
library(dplyr)
library(rvest)
library(stringr)

# --- 1. DATA LOADING ---
# Check if CSV exists, if not try to scrape it
if (!file.exists("homicides.csv")) {
  tryCatch({
    # Scrape data from the blog
    url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
    tables <- read_html(url) %>% html_nodes("table") %>% html_table(fill = TRUE)
    
    if (length(tables) > 0) {
      raw_data <- tables[[1]][, 1:7]
      colnames(raw_data) <- c("index", "date", "name", "age", "address", "method", "notes")
      
      df <- raw_data %>%
        filter(!is.na(method), method != "method") %>%
        mutate(
          age = suppressWarnings(as.numeric(age)),
          method_group = case_when(
            str_detect(method, regex("Shoot|Gun|Firearm|Gunshot", ignore_case = TRUE)) ~ "Shooting",
            str_detect(method, regex("Stab|Knife|Sharp|Cut", ignore_case = TRUE)) ~ "Stabbing",
            str_detect(method, regex("Blunt|Beating|Bludgeon|Club", ignore_case = TRUE)) ~ "Blunt Force",
            str_detect(method, regex("Strang|Asphyx|Choke", ignore_case = TRUE)) ~ "Strangulation",
            str_detect(method, regex("Trauma|Assault|Force", ignore_case = TRUE)) ~ "Other Violence",
            TRUE ~ "Other/Unknown"
          ),
          clean_date = as.Date(date, format = "%m/%d/%y"),
          month = as.integer(format(clean_date, "%m")),
          year = as.integer(format(clean_date, "%Y"))
        )
      
      write.csv(df, "homicides.csv", row.names = FALSE)
    }
  }, error = function(e) {
    warning("Could not scrape data: ", e$message)
  })
}

# Load from CSV (either existing or just created)
if (file.exists("homicides.csv")) {
  df <- read.csv("homicides.csv")
  
  # Parse date and extract month/year if not already present
  if (!("month" %in% colnames(df))) {
    df$clean_date <- as.Date(df$date, format = "%m/%d/%y")
    df$month <- as.integer(format(df$clean_date, "%m"))
    df$year <- as.integer(format(df$clean_date, "%Y"))
  }
  
  # Remove header rows and rows with invalid data
  df <- df[!is.na(df$month), ]
} else {
  # Fallback: create dummy data if everything fails
  df <- data.frame(
    month = 1:12, 
    method_group = "No Data Available", 
    age = 25, 
    name = "Data Loading Failed",
    year = 2025
  )
}

# Ensure age is numeric
df$age <- as.numeric(as.character(df$age))
df$age[is.na(df$age)] <- 0

# --- 2. USER INTERFACE ---
ui <- dashboardPage(
  skin = "red",
  dashboardHeader(title = "BPD Homicide Dashboard"),
  dashboardSidebar(
    checkboxGroupInput("method_filter", "Method Group:", 
                       choices = unique(df$method_group), 
                       selected = unique(df$method_group)),
    sliderInput("age_filter", "Victim Age:", 
                min = 0, max = 100, value = c(0, 100))
  ),
  dashboardBody(
    fluidRow(
      valueBoxOutput("stat_total", width = 6),
      valueBoxOutput("stat_age", width = 6)
    ),
    fluidRow(
      box(title = "Monthly Trend", plotlyOutput("month_plot"), width = 12)
    )
  )
)

# --- 3. SERVER ---
server <- function(input, output) {
  filtered_df <- reactive({
    df %>% filter(method_group %in% input$method_filter,
                  age >= input$age_filter[1],
                  age <= input$age_filter[2])
  })
  
  output$stat_total <- renderValueBox({
    valueBox(nrow(filtered_df()), "Total Homicides", icon = icon("list"), color = "red")
  })
  
  output$stat_age <- renderValueBox({
    avg_age <- if(nrow(filtered_df()) > 0) round(mean(filtered_df()$age, na.rm=T), 1) else 0
    valueBox(avg_age, "Average Age", icon = icon("user"), color = "blue")
  })
  
  output$month_plot <- renderPlotly({
    plot_ly(filtered_df(), x = ~month, type = "histogram") %>%
      layout(xaxis = list(title = "Month"), yaxis = list(title = "Count"))
  })
}

shinyApp(ui, server)