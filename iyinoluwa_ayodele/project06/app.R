#!/usr/bin/env Rscript

# Baltimore Homicide Dashboard - Shiny app for homicide analysis

suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(rvest)
  library(ggplot2)
  library(plotly)
  library(DT)
})

cache_path <- "data/baltimore_homicides.csv"

auto_create_data_dir <- function() {
  if (!dir.exists("data")) dir.create("data")
}

tidy_method <- function(notes) {
  notes <- tolower(notes)
  if (is.na(notes) || notes == "") return("Unknown")
  if (str_detect(notes, "shoot|gun|rifle|pistol|bullet")) return("Shooting")
  if (str_detect(notes, "stab|knife|cut|sharp")) return("Stabbing")
  if (str_detect(notes, "blunt|club|bat|hammer")) return("Blunt Force")
  if (str_detect(notes, "strang|asphyx|suffoc")) return("Asphyxiation")
  if (str_detect(notes, "arson|fire")) return("Arson")
  if (str_detect(notes, "vehic|hit and run|auto")) return("Vehicle")
  return("Other")
}

tidy_clearance <- function(notes) {
  notes <- tolower(notes)
  if (is.na(notes) || notes == "") return("Unknown")
  if (str_detect(notes, "cleared|arrest|suspect|solved|charge|indict")) return("Cleared")
  if (str_detect(notes, "open|investig|pending|unknown|unsolved|not cleared|cold")) return("Open")
  return("Unknown")
}

tidy_camera <- function(notes) {
  notes <- tolower(notes)
  if (is.na(notes) || notes == "") return("No")
  if (str_detect(notes, "camera|cctv|surveillance|video")) return("Yes")
  return("No")
}

fetch_year <- function(year) {
  url <- sprintf("https://chamspage.blogspot.com/%d/01/%d-baltimore-city-homicide-list.html", year, year)
  message("Fetching ", url)
  page <- tryCatch(read_html(url), error = function(e) {
    message("  failed read ", year, ": ", e$message)
    return(NULL)
  })
  if (is.null(page)) return(NULL)

  tbl <- page %>% html_node("table#homicidelist")
  if (is.null(tbl)) {
    message("  no table for year ", year)
    return(NULL)
  }

  df <- tbl %>% html_table(fill = TRUE)
  if (ncol(df) < 4) return(NULL)

  names(df)[1:6] <- c("No", "Date", "Name", "Age", "Location", "Notes")
  df$Year <- year
  return(df)
}

scrape_data <- function(years = 2017:year(Sys.Date())) {
  rows <- lapply(years, fetch_year)
  rows <- bind_rows(rows)
  if (nrow(rows) == 0) {
    stop("No rows scraped from data source")
  }

  cleaned <- rows %>%
    mutate(
      Date = suppressWarnings(mdy(Date)),
      Date = if_else(is.na(Date), suppressWarnings(ymd(Date)), Date),
      Age = as.numeric(str_extract(Age, "[0-9]+")),
      Location = as.character(Location),
      Notes = as.character(Notes),
      Method = sapply(Notes, tidy_method),
      CaseStatus = sapply(Notes, tidy_clearance),
      Camera = sapply(Notes, tidy_camera),
      Year = year(Date),
      Month = month(Date, label = TRUE, abbr = TRUE),
      DayOfWeek = wday(Date, label = TRUE, abbr = TRUE)
    ) %>%
    filter(!is.na(Date))

  cleaned
}

load_homicide_data <- function(force_refresh = FALSE) {
  auto_create_data_dir()
  if (!force_refresh && file.exists(cache_path)) {
    message("Loading cached homicide data from ", cache_path)
    dt <- read.csv(cache_path, stringsAsFactors = FALSE)
    dt$Date <- as.Date(dt$Date)
    dt$Month <- factor(dt$Month, levels = month.abb)
    return(dt)
  }

  message("Scraping homicide data pipeline...")
  dt <- tryCatch({
    scrape_data()
  }, error = function(e) {
    message("Scrape failed: ", e$message)
    NULL
  })

  if (is.null(dt) || nrow(dt) == 0) {
    if (file.exists(cache_path)) {
      message("Scrape failed. Loading stale cache.")
      dt <- read.csv(cache_path, stringsAsFactors = FALSE)
      dt$Date <- as.Date(dt$Date)
      dt$Month <- factor(dt$Month, levels = month.abb)
      return(dt)
    }
    stop("Unable to load homicide data from live scrape or cache.")
  }

  write.csv(dt, cache_path, row.names = FALSE)
  dt$Month <- factor(dt$Month, levels = month.abb)
  dt
}

homicide_data <- load_homicide_data()
if (nrow(homicide_data) == 0) {
  stop("No homicide data available after load")
}

year_choices <- sort(unique(homicide_data$Year))
method_choices <- sort(unique(homicide_data$Method))
status_choices <- sort(unique(homicide_data$CaseStatus))
camera_choices <- c("Any", "Yes", "No")

ui <- dashboardPage(
  dashboardHeader(title = "Baltimore Homicide Analysis"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "main", icon = icon("dashboard")),
      menuItem("Data Table", tabName = "table", icon = icon("table"))
    ),
    sliderInput("year", "Year range", min = min(year_choices), max = max(year_choices),
                value = c(min(year_choices), max(year_choices)), sep = ""),
    sliderInput("age", "Victim age range", min = 0, max = 100, value = c(14, 80)),
    selectInput("method", "Method", choices = method_choices, selected = method_choices,
                multiple = TRUE, selectize = TRUE),
    selectInput("status", "Case status", choices = c("Any", status_choices), selected = "Any"),
    selectInput("camera", "Camera coverage", choices = camera_choices, selected = "Any"),
    actionButton("refresh", "Refresh data (scrape live)", icon = icon("sync"))
  ),
  dashboardBody(
    tabItems(
      tabItem(tabName = "main",
              fluidRow(
                valueBoxOutput("totalBox", width = 3),
                valueBoxOutput("clearanceBox", width = 3),
                valueBoxOutput("avgAgeBox", width = 3),
                valueBoxOutput("cameraBox", width = 3)
              ),
              fluidRow(
                box(title = "Monthly Trend", status = "primary", solidHeader = TRUE,
                    width = 6, plotlyOutput("trendPlot", height = "330px")),
                box(title = "Method Distribution", status = "primary", solidHeader = TRUE,
                    width = 6, plotlyOutput("methodPlot", height = "330px"))
              ),
              fluidRow(
                box(title = "Method vs Month Heatmap", status = "primary", solidHeader = TRUE,
                    width = 6, plotlyOutput("heatmapPlot", height = "360px")),
                box(title = "Top Statistics", status = "info", solidHeader = TRUE,
                    width = 6,
                    htmlOutput("summaryText"),
                    br(),
                    tags$small("Data source: chamspage homicide lists (live scrape)"))
              )
      ),
      tabItem(tabName = "table",
              fluidRow(
                box(title = "Filtered Homicides", width = 12, status = "primary", solidHeader = TRUE,
                    DTOutput("filteredTable"))
              )
      )
    )
  )
)

server <- function(input, output, session) {
  filtered <- reactive({
    dt <- homicide_data %>%
      filter(Year >= input$year[1], Year <= input$year[2]) %>%
      filter(!is.na(Age) & Age >= input$age[1] & Age <= input$age[2])

    if (length(input$method) > 0) dt <- filter(dt, Method %in% input$method)
    if (input$status != "Any") dt <- filter(dt, CaseStatus == input$status)
    if (input$camera != "Any") dt <- filter(dt, Camera == input$camera)
    dt
  })

  observeEvent(input$refresh, {
    showModal(modalDialog("Refreshing data from live scrape... this may take 30s.", footer=NULL))
    newdata <- tryCatch({
      load_homicide_data(force_refresh = TRUE)
    }, error = function(e) {
      showNotification(paste("Refresh failed:", e$message), type = "error", duration = 5)
      NULL
    })
    removeModal()
    if (!is.null(newdata)) {
      homicide_data <<- newdata
      updateSliderInput(session, "year", min = min(homicide_data$Year), max = max(homicide_data$Year),
                        value = c(min(homicide_data$Year), max(homicide_data$Year)))
      updateSliderInput(session, "age", min = 0, max = max(100, max(homicide_data$Age, na.rm=TRUE)),
                        value = c(14, 80))
      updatePickerInput(session, "method", choices = sort(unique(homicide_data$Method)),
                        selected = sort(unique(homicide_data$Method)))
      showNotification("Live data refresh complete.", type = "message")
    }
  })

  output$totalBox <- renderValueBox({
    dt <- filtered()
    valueBox(formatC(nrow(dt), format="d", big.mark=","), "Filtered Homicides", icon = icon("skull"), color = "red")
  })

  output$clearanceBox <- renderValueBox({
    dt <- filtered()
    rate <- if (nrow(dt) == 0) NA else round(mean(dt$CaseStatus == "Cleared", na.rm=TRUE) * 100, 1)
    valueBox(ifelse(is.na(rate), "N/A", paste0(rate, "%")), "Clearance Rate", icon = icon("check-circle"), color = "green")
  })

  output$avgAgeBox <- renderValueBox({
    dt <- filtered()
    avg <- if (nrow(dt) == 0) NA else round(mean(dt$Age, na.rm=TRUE), 1)
    valueBox(ifelse(is.na(avg), "N/A", paste0(avg)), "Average Victim Age", icon = icon("user"), color = "blue")
  })

  output$cameraBox <- renderValueBox({
    dt <- filtered()
    pct <- if (nrow(dt) == 0) NA else round(mean(dt$Camera == "Yes", na.rm=TRUE) * 100, 1)
    valueBox(ifelse(is.na(pct), "N/A", paste0(pct, "%")), "Camera-Linked Incidents", icon = icon("video"), color = "purple")
  })

  output$trendPlot <- renderPlotly({
    dt <- filtered()
    if (nrow(dt) == 0) {
      p <- ggplot() + theme_void() + geom_text(aes(0,0,label="No data for selected filters"))
      return(ggplotly(p))
    }
    monthly <- dt %>%
      mutate(Monthly = floor_date(Date, "month")) %>%
      group_by(Monthly) %>%
      summarize(Incidents = n(), Cleared = sum(CaseStatus=="Cleared", na.rm=TRUE)) %>%
      mutate(ClearanceRate = ifelse(Incidents>0, 100*Cleared/Incidents, 0))
    p <- ggplot(monthly, aes(x=Monthly, y=Incidents)) +
      geom_col(fill="#C0392B") +
      geom_line(aes(y=ClearanceRate*1), group=1, color="#2471A3", size=1) +
      scale_y_continuous(
        name = "Incidents",
        sec.axis = sec_axis(~./1, name="Cleared count / rate (approx)")) +
      labs(title="Monthly Homicide Trend", x="Month", y="Incidents") +
      theme_minimal()
    ggplotly(p, height = 320)
  })

  output$methodPlot <- renderPlotly({
    dt <- filtered()
    if (nrow(dt) == 0) {
      p <- ggplot() + theme_void() + geom_text(aes(0,0,label="No data for selected filters"))
      return(ggplotly(p))
    }
    method_count <- dt %>% group_by(Method) %>% summarize(Count = n()) %>% arrange(desc(Count))
    p <- ggplot(method_count, aes(x=reorder(Method, Count), y=Count, fill=Method)) +
      geom_col(show.legend=FALSE) + coord_flip() +
      labs(title="Homicides by Method", x="Method", y="Count") + theme_minimal()
    ggplotly(p, height=320)
  })

  output$heatmapPlot <- renderPlotly({
    dt <- filtered()
    if (nrow(dt) == 0) {
      p <- ggplot() + theme_void() + geom_text(aes(0,0,label="No data for selected filters"))
      return(ggplotly(p))
    }
    heat <- dt %>% group_by(Month, Method) %>% summarize(Count = n(), .groups="drop")
    p <- ggplot(heat, aes(x=Month, y=Method, fill=Count)) +
      geom_tile(color="white") +
      scale_fill_gradient(low="#F7FBFF", high="#08519C") +
      labs(title="Monthly Method Heatmap", x="Month", y="Method") +
      theme_minimal()
    ggplotly(p, height = 360)
  })

  output$summaryText <- renderUI({
    dt <- filtered()
    if (nrow(dt) == 0) {
      HTML("<b>No data for this filter set.</b>")
    } else {
      top_method <- dt %>% count(Method, sort=TRUE) %>% slice(1) %>% pull(Method)
      y_min <- min(input$year)
      y_max <- max(input$year)
      prior <- homicide_data %>% filter(Year >= y_min-1, Year <= y_max-1)
      prior_count <- nrow(prior)
      current_count <- nrow(dt)
      diff <- if (prior_count == 0) NA else round(100*(current_count - prior_count)/prior_count, 1)
      HTML(sprintf("<ul><li><b>Most common method:</b> %s</li><li><b>Filtered incident count:</b> %d</li><li><b>Cases with clearance:</b> %s</li><li><b>Comparison to prior year range:</b> %s%%</li></ul>",
                   top_method,
                   current_count,
                   paste0(ifelse(mean(dt$CaseStatus=="Cleared",na.rm=TRUE)*100 > 0, sprintf("%.1f%%", mean(dt$CaseStatus=="Cleared",na.rm=TRUE)*100), "N/A")),
                   ifelse(is.na(diff), "N/A", as.character(diff))))
    }
  })

  output$filteredTable <- renderDT({
    dt <- filtered()
    if (nrow(dt) == 0) {
      datatable(data.frame(Note="No records match filters"), options = list(dom='t'))
    } else {
      datatable(dt %>% select(Date, Year, Age, Location, Method, CaseStatus, Camera, Notes),
                options=list(pageLength=10, scrollX=TRUE))
    }
  })
}

shinyApp(ui, server)
