library(shiny)
library(shinydashboard)
library(dplyr)
library(lubridate)
library(plotly)
library(rvest)
library(stringr)
library(readr)

# ---------------------------
#  PART 1 PIPELINE (INTEGRATED)
# ---------------------------
get_homicides <- function() {

  url <- "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html"

  is_numeric_case_no <- function(x) str_detect(x, "^\\s*\\d+\\s*$")

  make_age_bins <- function(age_vec, bin_size = 10, max_age = 100) {
    breaks <- c(seq(0, max_age, by = bin_size), Inf)
    labels <- c(
      paste0(seq(0, max_age - bin_size, by = bin_size), "-", seq(bin_size - 1, max_age - 1, by = bin_size)),
      paste0(max_age, "+")
    )
    cut(age_vec, breaks = breaks, right = FALSE, labels = labels, include.lowest = TRUE)
  }

  page <- read_html(url)
  tables <- page %>% html_elements("table")
  raw_tbl <- tables[[1]] %>% html_table(fill = TRUE)
  df <- raw_tbl[[1]]

  names(df) <- names(df) %>%
    str_replace_all("\\s+", " ") %>%
    str_trim() %>%
    make.names(unique = TRUE)

  col_no   <- names(df)[str_detect(names(df), "^No")][1]
  col_date <- names(df)[str_detect(names(df), "Date")][1]
  col_name <- names(df)[str_detect(names(df), "Name")][1]
  col_age  <- names(df)[str_detect(names(df), "Age")][1]

  clean <- df %>%
    mutate(
      CaseNo = as.character(.data[[col_no]]),
      DateDiedRaw = as.character(.data[[col_date]]),
      Name = as.character(.data[[col_name]]),
      AgeRaw = as.character(.data[[col_age]])
    ) %>%
    filter(!is.na(CaseNo), is_numeric_case_no(CaseNo)) %>%
    mutate(
      CaseNo = str_trim(CaseNo),
      DateDied = suppressWarnings(mdy(DateDiedRaw)),
      Age = suppressWarnings(parse_number(AgeRaw))
    ) %>%
    filter(!is.na(Age), Age >= 0, Age <= 120) %>%
    mutate(
      AgeBin = make_age_bins(Age),
      year = year(DateDied),
      month = month(DateDied, label = TRUE)
    )

  clean
}

dat <- get_homicides()

# ---------------------------
#  UI
# ---------------------------
ui <- dashboardPage(
  dashboardHeader(title = "Baltimore Homicide Dashboard"),
  dashboardSidebar(
    selectInput("year", "Year", choices = sort(unique(dat$year)),
                selected = max(dat$year), multiple = TRUE),
    sliderInput("age", "Victim Age", min(dat$Age), max(dat$Age),
                value = range(dat$Age)),
    checkboxInput("show_bins", "Show age bins instead of raw ages", FALSE)
  ),
  dashboardBody(
    fluidRow(
      valueBoxOutput("vb_total", 3),
      valueBoxOutput("vb_avg_age", 3),
      valueBoxOutput("vb_ytd", 3),
      valueBoxOutput("vb_most_common_bin", 3)
    ),
    fluidRow(
      box(width = 6, title = "Homicides by Month", solidHeader = TRUE,
          plotlyOutput("p_month")),
      box(width = 6, title = "Age Distribution", solidHeader = TRUE,
          plotlyOutput("p_age"))
    )
  )
)

# ---------------------------
#  SERVER
# ---------------------------
server <- function(input, output, session) {

  filt <- reactive({
    dat %>%
      filter(
        year %in% input$year,
        Age >= input$age[1],
        Age <= input$age[2]
      )
  })

  output$vb_total <- renderValueBox({
    valueBox(nrow(filt()), "Total Homicides", color = "red", icon = icon("skull"))
  })

  output$vb_avg_age <- renderValueBox({
    a <- round(mean(filt()$Age, na.rm = TRUE), 1)
    valueBox(a, "Average Age", color = "blue", icon = icon("user"))
  })

  output$vb_ytd <- renderValueBox({
    y <- max(filt()$year)
    n <- sum(filt()$year == y)
    valueBox(n, paste0("YTD (", y, ")"), color = "green", icon = icon("calendar"))
  })

  output$vb_most_common_bin <- renderValueBox({
    b <- filt() %>% count(AgeBin) %>% arrange(desc(n))
    top <- if (nrow(b) == 0) "N/A" else as.character(b$AgeBin[1])
    valueBox(top, "Most Common Age Bin", color = "purple", icon = icon("chart-bar"))
  })

  output$p_month <- renderPlotly({
    d <- filt() %>% count(month)
    plot_ly(d, x = ~month, y = ~n, type = "bar") %>%
      layout(yaxis = list(title = "Count"))
  })

  output$p_age <- renderPlotly({
    d <- filt()
    if (input$show_bins) {
      d <- d %>% count(AgeBin)
      plot_ly(d, x = ~AgeBin, y = ~n, type = "bar")
    } else {
      plot_ly(d, x = ~Age, type = "histogram", nbinsx = 20)
    }
  })
}

shinyApp(ui, server)