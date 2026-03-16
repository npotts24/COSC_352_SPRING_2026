library(shiny)
library(shinydashboard)
library(rvest)
library(dplyr)
library(stringr)
library(ggplot2)
library(lubridate)
library(plotly)
library(DT)

# --- Data Pipeline (from Part 1) ---
scrape_year <- function(url, year_label) {
  page <- tryCatch(read_html(url), error = function(e) return(NULL))
  if (is.null(page)) return(NULL)
  tables <- html_nodes(page, "table")
  if (length(tables) == 0) return(NULL)
  raw <- html_table(tables[[1]], fill = TRUE, header = FALSE)
  header_row <- which(apply(raw, 1, function(r) any(grepl("Date", r, ignore.case = TRUE))))[1]
  if (is.na(header_row)) header_row <- 1
  col_names <- str_trim(as.character(raw[header_row, ]))
  col_names[col_names == ""] <- paste0("V", seq_along(col_names[col_names == ""]))
  df <- raw[(header_row + 1):nrow(raw), ]
  names(df) <- make.unique(col_names)
  
  date_col <- names(df)[grepl("date|died", names(df), ignore.case = TRUE)][1]
  age_col <- names(df)[grepl("^age$", names(df), ignore.case = TRUE)][1]
  closed_col <- names(df)[grepl("closed", names(df), ignore.case = TRUE)][1]
  notes_col <- names(df)[grepl("notes", names(df), ignore.case = TRUE)][1]
  
  df %>% mutate(
    year = year_label,
    date_raw = str_trim(.data[[date_col]]),
    age_raw = if (!is.na(age_col)) str_trim(.data[[age_col]]) else NA_character_,
    closed_raw = if (!is.na(closed_col)) str_trim(.data[[closed_col]]) else NA_character_,
    notes_raw = if (!is.na(notes_col)) str_trim(.data[[notes_col]]) else NA_character_
  ) %>% select(year, date_raw, age_raw, closed_raw, notes_raw)
}

parse_date <- function(d) {
  d <- str_trim(d)
  p <- suppressWarnings(mdy(d))
  if (is.na(p) && grepl("^\\d{1,2}/\\d{4}$", d)) p <- suppressWarnings(mdy(paste0(d, "/01")))
  p
}

# Initial Scrape
url_2025 <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"
url_2024 <- "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html"
data_raw <- bind_rows(scrape_year(url_2025, 2025), scrape_year(url_2024, 2024))

full_data <- data_raw %>% 
  rowwise() %>% 
  mutate(date = parse_date(date_raw)) %>% 
  ungroup() %>%
  filter(!is.na(date)) %>%
  mutate(
    year = as.integer(year(date)),
    month = month(date, label = TRUE, abbr = TRUE),
    age = suppressWarnings(as.integer(str_extract(age_raw, "\\d+"))),
    status = if_else(str_detect(tolower(closed_raw), "closed"), "Closed", "Open"),
    method = case_when(
      str_detect(tolower(notes_raw), "stab") ~ "Stabbing",
      str_detect(tolower(notes_raw), "shoot|shot|gunshot") ~ "Shooting",
      TRUE ~ "Other/Unknown"
    )
  )

# --- UI ---
ui <- dashboardPage(
  dashboardHeader(title = "BPD Homicide Analysis"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Raw Data", tabName = "data", icon = icon("th"))
    ),
    hr(),
    selectInput("year_filter", "Select Year:", choices = c("All", sort(unique(full_data$year))), selected = "All"),
    checkboxGroupInput("method_filter", "Method:", choices = unique(full_data$method), selected = unique(full_data$method)),
    sliderInput("age_filter", "Victim Age Range:", min = 0, max = 100, value = c(0, 100))
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "dashboard",
        fluidRow(
          valueBoxOutput("total_homicides", width = 3),
          valueBoxOutput("clearance_rate", width = 3),
          valueBoxOutput("avg_age", width = 3),
          valueBoxOutput("top_method", width = 3)
        ),
        fluidRow(
          box(title = "Homicides by Month", status = "primary", solidHeader = TRUE, plotlyOutput("month_plot"), width = 8),
          box(title = "Method Distribution", status = "warning", solidHeader = TRUE, plotlyOutput("method_plot"), width = 4)
        )
      ),
      tabItem(tabName = "data",
        DTOutput("data_table")
      )
    )
  )
)

# --- Server ---
server <- function(input, output) {
  filtered_data <- reactive({
    df <- full_data
    if (input$year_filter != "All") df <- df %>% filter(year == as.integer(input$year_filter))
    df <- df %>% filter(method %in% input$method_filter)
    df <- df %>% filter(age >= input$age_filter[1], age <= input$age_filter[2] | is.na(age))
    df
  })
  
  output$total_homicides <- renderValueBox({
    valueBox(nrow(filtered_data()), "Total Homicides", icon = icon("skull"), color = "red")
  })
  
  output$clearance_rate <- renderValueBox({
    df <- filtered_data()
    rate <- if(nrow(df) > 0) round(sum(df$status == "Closed") / nrow(df) * 100, 1) else 0
    valueBox(paste0(rate, "%"), "Clearance Rate", icon = icon("check-circle"), color = "green")
  })
  
  output$avg_age <- renderValueBox({
    avg <- round(mean(filtered_data()$age, na.rm = TRUE), 1)
    valueBox(if(is.nan(avg)) "N/A" else avg, "Avg Victim Age", icon = icon("user"), color = "blue")
  })
  
  output$top_method <- renderValueBox({
    df <- filtered_data()
    top <- if(nrow(df) > 0) names(sort(table(df$method), decreasing = TRUE))[1] else "N/A"
    valueBox(top, "Most Common Method", icon = icon("exclamation-triangle"), color = "orange")
  })
  
  output$month_plot <- renderPlotly({
    p <- filtered_data() %>%
      count(year, month) %>%
      ggplot(aes(x = month, y = n, fill = factor(year))) +
      geom_bar(stat = "identity", position = "dodge") +
      theme_minimal() + labs(x = "Month", y = "Count", fill = "Year")
    ggplotly(p)
  })
  
  output$method_plot <- renderPlotly({
    p <- filtered_data() %>%
      count(method) %>%
      ggplot(aes(x = "", y = n, fill = method)) +
      geom_bar(stat = "identity", width = 1) +
      coord_polar("y", start = 0) +
      theme_void()
    ggplotly(p)
  })
  
  output$data_table <- renderDT({
    datatable(filtered_data() %>% select(year, date, age, status, method))
  })
}

shinyApp(ui, server)
