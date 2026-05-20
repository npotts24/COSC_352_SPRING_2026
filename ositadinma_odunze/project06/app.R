# Baltimore City Homicide Analysis Dashboard
# Author: Oc
# Course: COSC 352
# 
# Interactive Shiny dashboard for police department crime analysis

library(shiny)
library(shinydashboard)
library(dplyr)
library(ggplot2)
library(plotly)
library(DT)
library(lubridate)

# Data Generation Function (reusing Part 1 logic)
generate_homicide_data <- function() {
  cat("Loading homicide data...\n")
  
  # Generate realistic multi-year data
  set.seed(42)
  
  # Create 3 years of data (2023-2025)
  all_data <- data.frame()
  
  for (year in 2023:2025) {
    n <- sample(280:320, 1)  # Realistic annual homicide count for Baltimore
    
    # Realistic age distribution
    ages <- c(
      sample(12:17, round(n * 0.08), replace = TRUE),  # Juveniles 8%
      sample(18:24, round(n * 0.35), replace = TRUE),  # Young adults 35%
      sample(25:34, round(n * 0.30), replace = TRUE),  # Peak age 30%
      sample(35:49, round(n * 0.18), replace = TRUE),  # Middle age 18%
      sample(50:75, round(n * 0.09), replace = TRUE)   # Older 9%
    )
    
    # Ensure we have exactly n records
    ages <- ages[1:n]
    
    year_data <- data.frame(
      ID = paste0(year, "-", sprintf("%03d", 1:n)),
      Year = year,
      Month = sample(1:12, n, replace = TRUE),
      Day = sample(1:28, n, replace = TRUE),
      VictimAge = ages,
      Method = sample(
        c("Shooting", "Shooting", "Shooting", "Shooting", "Shooting",
          "Stabbing", "Blunt Force", "Other"),
        n, replace = TRUE
      ),
      District = sample(
        c("Central", "Eastern", "Northeastern", "Northern", 
          "Northwestern", "Southern", "Southeastern", "Southwestern", "Western"),
        n, replace = TRUE
      ),
      CCTV = sample(c("Yes", "No"), n, replace = TRUE, prob = c(0.35, 0.65)),
      CaseClosed = sample(c("Yes", "No"), n, replace = TRUE, prob = c(0.25, 0.75)),
      stringsAsFactors = FALSE
    )
    
    # Add date column
    year_data$Date <- as.Date(paste(year_data$Year, year_data$Month, year_data$Day, sep = "-"))
    
    all_data <- rbind(all_data, year_data)
  }
  
  cat("Generated", nrow(all_data), "homicide records from 2023-2025\n")
  return(all_data)
}

# Load data at startup
homicide_data <- generate_homicide_data()

# UI Definition
ui <- dashboardPage(
  skin = "blue",
  
  dashboardHeader(
    title = "Baltimore PD Homicide Analysis",
    titleWidth = 300
  ),
  
  dashboardSidebar(
    width = 300,
    sidebarMenu(
      menuItem("Overview", tabName = "overview", icon = icon("dashboard")),
      menuItem("Trends", tabName = "trends", icon = icon("chart-line")),
      menuItem("Demographics", tabName = "demographics", icon = icon("users")),
      menuItem("Geographic", tabName = "geographic", icon = icon("map")),
      menuItem("Data Table", tabName = "data", icon = icon("table"))
    ),
    
    hr(),
    
    h4("Filters", style = "padding-left: 15px; color: white;"),
    
    # Year Range
    sliderInput("year_range",
                "Year Range:",
                min = 2023,
                max = 2025,
                value = c(2023, 2025),
                step = 1,
                sep = ""),
    
    # Age Range
    sliderInput("age_range",
                "Victim Age:",
                min = 10,
                max = 80,
                value = c(10, 80)),
    
    # Method Filter
    checkboxGroupInput("methods",
                       "Method:",
                       choices = c("Shooting", "Stabbing", "Blunt Force", "Other"),
                       selected = c("Shooting", "Stabbing", "Blunt Force", "Other")),
    
    # Case Status
    radioButtons("case_status",
                 "Case Status:",
                 choices = c("All" = "all",
                           "Closed Only" = "closed",
                           "Open Only" = "open"),
                 selected = "all"),
    
    # CCTV Filter
    radioButtons("cctv_filter",
                 "CCTV Presence:",
                 choices = c("All" = "all",
                           "With CCTV" = "yes",
                           "Without CCTV" = "no"),
                 selected = "all")
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .main-header .logo {
          font-weight: bold;
          font-size: 18px;
        }
        .box-title {
          font-size: 18px;
          font-weight: bold;
        }
        .small-box {
          border-radius: 5px;
        }
      "))
    ),
    
    tabItems(
      # Overview Tab
      tabItem(
        tabName = "overview",
        h2("Executive Summary"),
        
        fluidRow(
          valueBoxOutput("total_homicides", width = 3),
          valueBoxOutput("clearance_rate", width = 3),
          valueBoxOutput("avg_age", width = 3),
          valueBoxOutput("cctv_coverage", width = 3)
        ),
        
        fluidRow(
          box(
            title = "Homicides Over Time",
            status = "primary",
            solidHeader = TRUE,
            width = 8,
            plotlyOutput("timeline_plot", height = "350px")
          ),
          box(
            title = "Method Breakdown",
            status = "primary",
            solidHeader = TRUE,
            width = 4,
            plotlyOutput("method_pie", height = "350px")
          )
        ),
        
        fluidRow(
          box(
            title = "Key Insights",
            status = "info",
            solidHeader = TRUE,
            width = 12,
            uiOutput("insights_text")
          )
        )
      ),
      
      # Trends Tab
      tabItem(
        tabName = "trends",
        h2("Temporal Analysis"),
        
        fluidRow(
          box(
            title = "Monthly Trend",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            plotlyOutput("monthly_trend", height = "400px")
          )
        ),
        
        fluidRow(
          box(
            title = "Clearance Rate Over Time",
            status = "primary",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("clearance_trend", height = "350px")
          ),
          box(
            title = "Cases by Day of Week",
            status = "primary",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("dow_chart", height = "350px")
          )
        )
      ),
      
      # Demographics Tab
      tabItem(
        tabName = "demographics",
        h2("Victim Demographics"),
        
        fluidRow(
          box(
            title = "Age Distribution",
            status = "primary",
            solidHeader = TRUE,
            width = 8,
            plotlyOutput("age_histogram", height = "400px")
          ),
          box(
            title = "Age Statistics",
            status = "info",
            solidHeader = TRUE,
            width = 4,
            tableOutput("age_stats_table")
          )
        ),
        
        fluidRow(
          box(
            title = "Method by Age Group",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            plotlyOutput("method_by_age", height = "400px")
          )
        )
      ),
      
      # Geographic Tab
      tabItem(
        tabName = "geographic",
        h2("Geographic Distribution"),
        
        fluidRow(
          box(
            title = "Cases by District",
            status = "primary",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("district_bar", height = "500px")
          ),
          box(
            title = "CCTV Impact by District",
            status = "primary",
            solidHeader = TRUE,
            width = 6,
            plotlyOutput("cctv_district", height = "500px")
          )
        )
      ),
      
      # Data Table Tab
      tabItem(
        tabName = "data",
        h2("Filtered Data"),
        
        fluidRow(
          box(
            title = "Download Filtered Data",
            status = "primary",
            solidHeader = TRUE,
            width = 12,
            downloadButton("download_data", "Download CSV"),
            hr(),
            DTOutput("data_table")
          )
        )
      )
    )
  )
)

# Server Logic
server <- function(input, output, session) {
  
  # Reactive filtered dataset
  filtered_data <- reactive({
    data <- homicide_data
    
    # Year filter
    data <- data %>%
      filter(Year >= input$year_range[1] & Year <= input$year_range[2])
    
    # Age filter
    data <- data %>%
      filter(VictimAge >= input$age_range[1] & VictimAge <= input$age_range[2])
    
    # Method filter
    if (length(input$methods) > 0) {
      data <- data %>% filter(Method %in% input$methods)
    } else {
      data <- data %>% filter(FALSE)  # No methods selected = no data
    }
    
    # Case status filter
    if (input$case_status == "closed") {
      data <- data %>% filter(CaseClosed == "Yes")
    } else if (input$case_status == "open") {
      data <- data %>% filter(CaseClosed == "No")
    }
    
    # CCTV filter
    if (input$cctv_filter == "yes") {
      data <- data %>% filter(CCTV == "Yes")
    } else if (input$cctv_filter == "no") {
      data <- data %>% filter(CCTV == "No")
    }
    
    return(data)
  })
  
  # Value Boxes
  output$total_homicides <- renderValueBox({
    valueBox(
      nrow(filtered_data()),
      "Total Homicides",
      icon = icon("exclamation-triangle"),
      color = "red"
    )
  })
  
  output$clearance_rate <- renderValueBox({
    data <- filtered_data()
    if (nrow(data) > 0) {
      rate <- round(sum(data$CaseClosed == "Yes") / nrow(data) * 100, 1)
    } else {
      rate <- 0
    }
    valueBox(
      paste0(rate, "%"),
      "Clearance Rate",
      icon = icon("check-circle"),
      color = if (rate >= 30) "green" else if (rate >= 20) "yellow" else "red"
    )
  })
  
  output$avg_age <- renderValueBox({
    data <- filtered_data()
    if (nrow(data) > 0) {
      avg <- round(mean(data$VictimAge, na.rm = TRUE), 1)
    } else {
      avg <- 0
    }
    valueBox(
      paste0(avg, " years"),
      "Average Victim Age",
      icon = icon("user"),
      color = "blue"
    )
  })
  
  output$cctv_coverage <- renderValueBox({
    data <- filtered_data()
    if (nrow(data) > 0) {
      cctv_pct <- round(sum(data$CCTV == "Yes") / nrow(data) * 100, 1)
    } else {
      cctv_pct <- 0
    }
    valueBox(
      paste0(cctv_pct, "%"),
      "Near CCTV",
      icon = icon("video"),
      color = "purple"
    )
  })
  
  # Timeline Plot
  output$timeline_plot <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    monthly_counts <- data %>%
      mutate(YearMonth = floor_date(Date, "month")) %>%
      group_by(YearMonth) %>%
      summarise(Count = n(), .groups = 'drop')
    
    p <- ggplot(monthly_counts, aes(x = YearMonth, y = Count)) +
      geom_line(color = "#3498db", size = 1.2) +
      geom_point(color = "#2c3e50", size = 2) +
      labs(title = NULL, x = "Date", y = "Number of Homicides") +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 14, face = "bold"),
        axis.title = element_text(size = 11)
      )
    
    ggplotly(p, tooltip = c("x", "y"))
  })
  
  # Method Pie Chart
  output$method_pie <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    method_counts <- data %>%
      group_by(Method) %>%
      summarise(Count = n(), .groups = 'drop')
    
    plot_ly(method_counts, labels = ~Method, values = ~Count, type = 'pie',
            textinfo = 'label+percent',
            marker = list(colors = c('#e74c3c', '#3498db', '#f39c12', '#95a5a6'))) %>%
      layout(showlegend = TRUE)
  })
  
  # Insights Text
  output$insights_text <- renderUI({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(HTML("<p>No data matches current filters.</p>"))
    }
    
    clearance_rate <- round(sum(data$CaseClosed == "Yes") / nrow(data) * 100, 1)
    most_common_method <- names(sort(table(data$Method), decreasing = TRUE))[1]
    peak_month <- names(sort(table(data$Month), decreasing = TRUE))[1]
    
    HTML(paste0(
      "<ul>",
      "<li><strong>", nrow(data), "</strong> homicides match the current filters</li>",
      "<li>Most common method: <strong>", most_common_method, "</strong></li>",
      "<li>Case clearance rate: <strong>", clearance_rate, "%</strong></li>",
      "<li>Peak month: <strong>", month.name[as.numeric(peak_month)], "</strong></li>",
      "</ul>"
    ))
  })
  
  # Monthly Trend
  output$monthly_trend <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    monthly <- data %>%
      group_by(Year, Month) %>%
      summarise(Count = n(), .groups = 'drop') %>%
      mutate(YearMonth = as.Date(paste(Year, Month, "01", sep = "-")))
    
    p <- ggplot(monthly, aes(x = Month, y = Count, color = factor(Year), group = Year)) +
      geom_line(size = 1.2) +
      geom_point(size = 2.5) +
      scale_x_continuous(breaks = 1:12, labels = month.abb) +
      labs(title = NULL, x = "Month", y = "Homicides", color = "Year") +
      theme_minimal() +
      theme(legend.position = "top")
    
    ggplotly(p)
  })
  
  # Clearance Trend
  output$clearance_trend <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    clearance_by_month <- data %>%
      mutate(YearMonth = floor_date(Date, "month")) %>%
      group_by(YearMonth) %>%
      summarise(
        Total = n(),
        Closed = sum(CaseClosed == "Yes"),
        Rate = round(Closed / Total * 100, 1),
        .groups = 'drop'
      )
    
    p <- ggplot(clearance_by_month, aes(x = YearMonth, y = Rate)) +
      geom_line(color = "#27ae60", size = 1.2) +
      geom_point(color = "#16a085", size = 2.5) +
      geom_hline(yintercept = 25, linetype = "dashed", color = "red", alpha = 0.7) +
      labs(title = NULL, x = "Date", y = "Clearance Rate (%)") +
      theme_minimal()
    
    ggplotly(p)
  })
  
  # Day of Week Chart
  output$dow_chart <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    dow_data <- data %>%
      mutate(DayOfWeek = wday(Date, label = TRUE, week_start = 1)) %>%
      group_by(DayOfWeek) %>%
      summarise(Count = n(), .groups = 'drop')
    
    p <- ggplot(dow_data, aes(x = DayOfWeek, y = Count, fill = DayOfWeek)) +
      geom_col(show.legend = FALSE) +
      labs(title = NULL, x = "Day of Week", y = "Number of Cases") +
      theme_minimal() +
      scale_fill_brewer(palette = "Set3")
    
    ggplotly(p)
  })
  
  # Age Histogram
  output$age_histogram <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    p <- ggplot(data, aes(x = VictimAge)) +
      geom_histogram(binwidth = 5, fill = "#3498db", color = "white", alpha = 0.8) +
      labs(title = NULL, x = "Age (years)", y = "Number of Victims") +
      theme_minimal()
    
    ggplotly(p)
  })
  
  # Age Statistics Table
  output$age_stats_table <- renderTable({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(data.frame(Statistic = "No data", Value = ""))
    }
    
    data.frame(
      Statistic = c("Mean", "Median", "Min", "Max", "Std Dev"),
      Value = c(
        round(mean(data$VictimAge), 1),
        median(data$VictimAge),
        min(data$VictimAge),
        max(data$VictimAge),
        round(sd(data$VictimAge), 1)
      )
    )
  }, striped = TRUE, hover = TRUE)
  
  # Method by Age
  output$method_by_age <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    data <- data %>%
      mutate(AgeGroup = cut(VictimAge, 
                           breaks = c(0, 18, 25, 35, 50, 100),
                           labels = c("Under 18", "18-24", "25-34", "35-49", "50+")))
    
    method_age <- data %>%
      group_by(AgeGroup, Method) %>%
      summarise(Count = n(), .groups = 'drop')
    
    p <- ggplot(method_age, aes(x = AgeGroup, y = Count, fill = Method)) +
      geom_col(position = "dodge") +
      labs(title = NULL, x = "Age Group", y = "Number of Cases") +
      theme_minimal() +
      theme(legend.position = "top")
    
    ggplotly(p)
  })
  
  # District Bar Chart
  output$district_bar <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    district_counts <- data %>%
      group_by(District) %>%
      summarise(Count = n(), .groups = 'drop') %>%
      arrange(desc(Count))
    
    p <- ggplot(district_counts, aes(x = reorder(District, Count), y = Count)) +
      geom_col(fill = "#e74c3c", alpha = 0.8) +
      coord_flip() +
      labs(title = NULL, x = "District", y = "Number of Homicides") +
      theme_minimal()
    
    ggplotly(p)
  })
  
  # CCTV by District
  output$cctv_district <- renderPlotly({
    data <- filtered_data()
    
    if (nrow(data) == 0) {
      return(plotly_empty())
    }
    
    cctv_data <- data %>%
      group_by(District, CCTV) %>%
      summarise(Count = n(), .groups = 'drop')
    
    p <- ggplot(cctv_data, aes(x = District, y = Count, fill = CCTV)) +
      geom_col(position = "dodge") +
      coord_flip() +
      labs(title = NULL, x = "District", y = "Number of Cases") +
      theme_minimal() +
      scale_fill_manual(values = c("Yes" = "#27ae60", "No" = "#95a5a6")) +
      theme(legend.position = "top")
    
    ggplotly(p)
  })
  
  # Data Table
  output$data_table <- renderDT({
    data <- filtered_data() %>%
      select(ID, Date, VictimAge, Method, District, CCTV, CaseClosed) %>%
      arrange(desc(Date))
    
    datatable(data, 
              options = list(pageLength = 25, scrollX = TRUE),
              rownames = FALSE)
  })
  
  # Download Handler
  output$download_data <- downloadHandler(
    filename = function() {
      paste0("baltimore_homicides_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )
}

# Run the application
shinyApp(ui = ui, server = server)