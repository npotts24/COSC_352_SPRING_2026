suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(plotly)
  library(DT)
  library(rvest)
  library(dplyr)
  library(tibble)
  library(stringr)
  library(ggplot2)
  library(lubridate)
})

source_pages <- c(
  "2025" = "https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html",
  "2024" = "https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html",
  "2023" = "https://chamspage.blogspot.com/2023/",
  "2022" = "https://chamspage.blogspot.com/2022/"
)

cache_file <- "homicides_cache.csv"

combine_split_rows <- function(rows) {
  rows <- rows[nzchar(rows)]
  rows <- rows[!str_detect(rows, "^No\\. Date Died")]

  combined <- character(0)

  for (row in rows) {
    row <- str_squish(row)

    if (str_detect(row, "^(\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\b")) {
      combined <- c(combined, row)
      next
    }

    if (
      length(combined) > 0 &&
      str_detect(
        row,
        "^(None|Closed|\\d+\\s+cameras?|None\\s+Closed|None\\s+\\d+\\s+cameras?|\\d+\\s+cameras?\\s+Closed)$"
      )
    ) {
      combined[length(combined)] <- str_trim(paste(combined[length(combined)], row))
    }
  }

  combined
}

extract_address <- function(text_after_age) {
  street_pattern <- paste0(
    "^(\\d+\\s+[A-Za-z0-9'\\-\\. ]+?(?:",
    "Street|Avenue|Road|Court|Lane|Way|Boulevard|Drive|Place|Terrace|",
    "Highway|Circle|Row|Parkway|Pike|Alley|Avaenue|Plaza|Square|Loop|Gardens",
    "))\\b"
  )

  intersection_pattern <- "^([A-Za-z0-9'\\-\\. ]+?\\s+and\\s+[A-Za-z0-9'\\-\\. ]+)"
  highway_pattern <- "^(I-\\d+[^\\.]+)"

  address <- str_match(text_after_age, street_pattern)[, 2]

  if (is.na(address)) {
    address <- str_match(text_after_age, intersection_pattern)[, 2]
  }

  if (is.na(address)) {
    address <- str_match(text_after_age, highway_pattern)[, 2]
  }

  address <- str_replace(address, "\\.$", "")
  str_squish(address)
}

classify_method <- function(text) {
  lower_text <- str_to_lower(text)

  case_when(
    str_detect(lower_text, "stabb") ~ "Stabbing",
    str_detect(lower_text, "shoot|gunshot") ~ "Shooting",
    str_detect(lower_text, "assault|beating") ~ "Assault / Beating",
    str_detect(lower_text, "blunt") ~ "Blunt Force",
    str_detect(lower_text, "strangl|asphyx") ~ "Strangulation / Asphyxiation",
    str_detect(lower_text, "burn") ~ "Burning",
    TRUE ~ "Other / Unknown"
  )
}

extract_camera_count <- function(text) {
  as.integer(str_match(str_to_lower(text), "(\\d+)\\s+cameras?")[, 2])
}

extract_camera_label <- function(text, camera_count) {
  lower_text <- str_to_lower(text)

  case_when(
    !is.na(camera_count) & camera_count > 0 ~ "Nearby camera",
    str_detect(lower_text, "no cctv|no cameras on this block|no surveillance camera") ~ "No nearby camera",
    str_detect(lower_text, "\\bnone\\b(\\s+closed)?$") ~ "No nearby camera",
    TRUE ~ "Unknown"
  )
}

parse_one_year <- function(url, year_num) {
  message("Loading ", year_num, " data from ", url)
  page <- tryCatch(read_html(url), error = function(e) NULL)

  if (is.null(page)) {
    warning("Could not open page: ", url, call. = FALSE)
    return(tibble())
  }

  raw_rows <- page %>%
    html_elements("table tr") %>%
    html_text2() %>%
    str_squish()

  raw_rows <- combine_split_rows(raw_rows)
  record_rows <- raw_rows[str_detect(raw_rows, "^(\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\b")]

  if (length(record_rows) == 0) {
    warning("No records matched the expected format for year ", year_num, call. = FALSE)
    return(tibble())
  }

  parsed <- tibble(raw_row = record_rows) %>%
    mutate(
      case_number = str_match(raw_row, "^((?:\\d{3}|XXX))")[, 2],
      date_text = str_match(raw_row, "^(?:\\d{3}|XXX)\\s+(\\d{1,2}/\\d{1,2}/\\d{2})")[, 2],
      name = str_trim(
        str_match(
          raw_row,
          "^(?:\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\s+(.+?)\\s+\\d{1,3}\\b"
        )[, 2]
      ),
      age = as.integer(
        str_match(
          raw_row,
          "^(?:\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\s+.+?\\s+(\\d{1,3})\\b"
        )[, 2]
      ),
      text_after_age = str_replace(
        raw_row,
        "^(?:\\d{3}|XXX)\\s+\\d{1,2}/\\d{1,2}/\\d{2}\\s+.+?\\s+\\d{1,3}\\s+",
        ""
      ),
      address = vapply(text_after_age, extract_address, character(1)),
      street_name = ifelse(
        !is.na(address),
        str_squish(str_remove(address, "^\\d+\\s+")),
        "Unknown"
      ),
      block_label = ifelse(
        !is.na(address),
        paste0(str_extract(address, "^\\d+"), " block of ", street_name),
        "Unknown"
      ),
      method = classify_method(raw_row),
      camera_count = extract_camera_count(raw_row),
      camera_label = extract_camera_label(raw_row, camera_count),
      case_status = ifelse(str_detect(raw_row, "\\bClosed\\b"), "Closed", "Open / Unknown"),
      year = year_num,
      date = mdy(date_text)
    ) %>%
    filter(!is.na(date), !is.na(name), !is.na(age), age > 0, age < 110, year(date) == year_num) %>%
    mutate(
      month_start = floor_date(date, "month"),
      month_label = factor(month(date, label = TRUE, abbr = TRUE), levels = month.abb),
      case_closed = case_status == "Closed",
      camera_nearby = ifelse(
        camera_label == "Nearby camera",
        TRUE,
        ifelse(camera_label == "No nearby camera", FALSE, NA)
      )
    ) %>%
    distinct(year, case_number, .keep_all = TRUE) %>%
    select(
      year,
      case_number,
      date,
      month_start,
      month_label,
      name,
      age,
      address,
      street_name,
      block_label,
      method,
      case_status,
      case_closed,
      camera_count,
      camera_label,
      camera_nearby,
      raw_row
    )

  parsed
}

scrape_homicide_data <- function() {
  bind_rows(lapply(names(source_pages), function(year_value) {
    parse_one_year(source_pages[[year_value]], as.integer(year_value))
  }))
}

load_homicide_data <- function() {
  live_data <- tryCatch(scrape_homicide_data(), error = function(e) NULL)

  if (!is.null(live_data) && nrow(live_data) > 0) {
    write.csv(live_data, cache_file, row.names = FALSE)
    return(live_data)
  }

  if (file.exists(cache_file)) {
    cached <- read.csv(cache_file, stringsAsFactors = FALSE)

    cached <- cached %>%
      mutate(
        year = as.integer(year),
        age = as.integer(age),
        camera_count = as.integer(camera_count),
        date = as.Date(date),
        month_start = as.Date(month_start),
        month_label = factor(month_label, levels = month.abb),
        case_closed = case_status == "Closed",
        camera_nearby = ifelse(
          camera_label == "Nearby camera",
          TRUE,
          ifelse(camera_label == "No nearby camera", FALSE, NA)
        )
      )

    return(cached)
  }

  stop("No homicide data could be loaded. Live scrape failed and no cache file was found.")
}

homicide_data <- load_homicide_data()

min_date <- min(homicide_data$date, na.rm = TRUE)
max_date <- max(homicide_data$date, na.rm = TRUE)
year_choices <- sort(unique(homicide_data$year))
method_choices <- sort(unique(homicide_data$method))
block_choices <- sort(unique(homicide_data$block_label))
age_min <- min(homicide_data$age, na.rm = TRUE)
age_max <- max(homicide_data$age, na.rm = TRUE)

empty_plot <- function(title_text) {
  plot_ly() %>%
    layout(
      title = list(text = title_text),
      xaxis = list(visible = FALSE),
      yaxis = list(visible = FALSE),
      annotations = list(
        list(
          text = "No records match the current filters.",
          x = 0.5,
          y = 0.5,
          showarrow = FALSE,
          xref = "paper",
          yref = "paper"
        )
      )
    )
}

ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(
    title = "Baltimore Homicide Dashboard",
    titleWidth = 300
  ),
  dashboardSidebar(
    width = 300,
    sidebarMenu(
      menuItem("Filters", tabName = "filters", icon = icon("filter")),
      dateRangeInput(
        "date_filter",
        "Date range",
        start = min_date,
        end = max_date,
        min = min_date,
        max = max_date
      ),
      checkboxGroupInput(
        "year_filter",
        "Years",
        choices = year_choices,
        selected = year_choices
      ),
      sliderInput(
        "age_filter",
        "Victim age",
        min = age_min,
        max = age_max,
        value = c(age_min, age_max)
      ),
      checkboxGroupInput(
        "method_filter",
        "Method",
        choices = method_choices,
        selected = method_choices
      ),
      selectInput(
        "status_filter",
        "Case status",
        choices = c("All", "Closed", "Open / Unknown"),
        selected = "All"
      ),
      selectInput(
        "camera_filter",
        "Camera coverage",
        choices = c("All", "Nearby camera", "No nearby camera", "Unknown"),
        selected = "All"
      ),
      selectizeInput(
        "block_filter",
        "Area / block",
        choices = block_choices,
        multiple = TRUE,
        options = list(placeholder = "Leave blank for all areas")
      ),
      actionButton("reset_filters", "Reset filters"),
      br(),
      br(),
      downloadButton("download_filtered", "Download filtered CSV")
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .skin-blue .main-header .logo,
        .skin-blue .main-header .navbar {
          background-color: #102a43;
        }
        .skin-blue .main-sidebar {
          background-color: #1f2d3d;
        }
        .content-wrapper,
        .right-side {
          background-color: #f4f6f8;
        }
        .box {
          border-top: 3px solid #102a43;
        }
        .summary-strip {
          background: #ffffff;
          border-left: 4px solid #d9822b;
          padding: 12px 16px;
          font-size: 15px;
          margin-bottom: 15px;
        }
      "))
    ),
    fluidRow(
      valueBoxOutput("total_box", width = 3),
      valueBoxOutput("clearance_box", width = 3),
      valueBoxOutput("avg_age_box", width = 3),
      valueBoxOutput("camera_box", width = 3)
    ),
    fluidRow(
      box(width = 12, htmlOutput("summary_strip"))
    ),
    fluidRow(
      box(width = 8, title = "Monthly trend", status = "primary", solidHeader = TRUE, plotlyOutput("monthly_plot", height = 320)),
      box(width = 4, title = "Method breakdown", status = "primary", solidHeader = TRUE, plotlyOutput("method_plot", height = 320))
    ),
    fluidRow(
      box(width = 6, title = "Victim age distribution", status = "primary", solidHeader = TRUE, plotlyOutput("age_plot", height = 320)),
      box(width = 6, title = "Top incident locations", status = "primary", solidHeader = TRUE, plotlyOutput("location_plot", height = 320))
    ),
    fluidRow(
      box(width = 12, title = "Filtered incidents", status = "primary", solidHeader = TRUE, DTOutput("incident_table"))
    )
  )
)

server <- function(input, output, session) {
  filtered_data <- reactive({
    req(input$date_filter, input$age_filter)

    data <- homicide_data

    if (!is.null(input$year_filter) && length(input$year_filter) > 0) {
      data <- data %>% filter(year %in% input$year_filter)
    } else {
      data <- data[0, ]
    }

    if (!is.null(input$method_filter) && length(input$method_filter) > 0) {
      data <- data %>% filter(method %in% input$method_filter)
    } else {
      data <- data[0, ]
    }

    data <- data %>%
      filter(
        date >= input$date_filter[1],
        date <= input$date_filter[2],
        age >= input$age_filter[1],
        age <= input$age_filter[2]
      )

    if (input$status_filter != "All") {
      data <- data %>% filter(case_status == input$status_filter)
    }

    if (input$camera_filter != "All") {
      data <- data %>% filter(camera_label == input$camera_filter)
    }

    if (!is.null(input$block_filter) && length(input$block_filter) > 0) {
      data <- data %>% filter(block_label %in% input$block_filter)
    }

    data %>% arrange(desc(date), name)
  })

  observeEvent(input$reset_filters, {
    updateDateRangeInput(session, "date_filter", start = min_date, end = max_date)
    updateCheckboxGroupInput(session, "year_filter", selected = year_choices)
    updateSliderInput(session, "age_filter", value = c(age_min, age_max))
    updateCheckboxGroupInput(session, "method_filter", selected = method_choices)
    updateSelectInput(session, "status_filter", selected = "All")
    updateSelectInput(session, "camera_filter", selected = "All")
    updateSelectizeInput(session, "block_filter", selected = character(0))
  })

  output$total_box <- renderValueBox({
    valueBox(
      value = format(nrow(filtered_data()), big.mark = ","),
      subtitle = "Filtered homicides",
      icon = icon("list"),
      color = "navy"
    )
  })

  output$clearance_box <- renderValueBox({
    data <- filtered_data()
    clearance_rate <- if (nrow(data) == 0) 0 else round(mean(data$case_closed) * 100, 1)

    valueBox(
      value = paste0(clearance_rate, "%"),
      subtitle = "Clearance rate",
      icon = icon("check-circle"),
      color = "olive"
    )
  })

  output$avg_age_box <- renderValueBox({
    data <- filtered_data()
    avg_age <- if (nrow(data) == 0) "N/A" else sprintf("%.1f", mean(data$age))

    valueBox(
      value = avg_age,
      subtitle = "Average victim age",
      icon = icon("user"),
      color = "orange"
    )
  })

  output$camera_box <- renderValueBox({
    data <- filtered_data() %>% filter(camera_label != "Unknown")
    camera_rate <- if (nrow(data) == 0) "N/A" else paste0(round(mean(data$camera_label == "Nearby camera") * 100, 1), "%")

    valueBox(
      value = camera_rate,
      subtitle = "Incidents near CCTV",
      icon = icon("video-camera"),
      color = "teal"
    )
  })

  output$summary_strip <- renderUI({
    data <- filtered_data()

    if (nrow(data) == 0) {
      return(tags$div(class = "summary-strip", "No incidents match the current filters."))
    }

    top_method <- data %>% count(method, sort = TRUE) %>% slice(1) %>% pull(method)
    known_blocks <- data %>% filter(block_label != "Unknown")
    top_block <- if (nrow(known_blocks) == 0) {
      "Unknown"
    } else {
      known_blocks %>% count(block_label, sort = TRUE) %>% slice(1) %>% pull(block_label)
    }

    tags$div(
      class = "summary-strip",
      HTML(
        paste0(
          "<strong>Most common method:</strong> ", top_method,
          " &nbsp;&nbsp; <strong>Top location:</strong> ", top_block,
          " &nbsp;&nbsp; <strong>Years in view:</strong> ", paste(sort(unique(data$year)), collapse = ", "),
          " &nbsp;&nbsp; <strong>Records loaded at startup:</strong> ", format(nrow(homicide_data), big.mark = ",")
        )
      )
    )
  })

  output$monthly_plot <- renderPlotly({
    data <- filtered_data()

    if (nrow(data) == 0) {
      return(empty_plot("Monthly trend"))
    }

    plot_data <- data %>%
      mutate(month_number = month(date)) %>%
      count(year, month_number, month_label, name = "count") %>%
      mutate(
        hover_text = paste0(
          "Year: ", year,
          "<br>Month: ", month.abb[month_number],
          "<br>Homicides: ", count
        )
      )

    plot_obj <- ggplot(
      plot_data,
      aes(
        x = month_number,
        y = count,
        color = factor(year),
        group = factor(year),
        text = hover_text
      )
    ) +
      geom_line(linewidth = 1) +
      geom_point(size = 2) +
      scale_x_continuous(
        breaks = 1:12,
        labels = month.abb,
        limits = c(1, 12)
      ) +
      labs(
        x = "Month",
        y = "Homicides",
        color = "Year"
      ) +
      theme_minimal()

    ggplotly(plot_obj, tooltip = "text")
  })

  output$method_plot <- renderPlotly({
    data <- filtered_data()

    if (nrow(data) == 0) {
      return(empty_plot("Method breakdown"))
    }

    plot_data <- data %>%
      count(method, sort = TRUE) %>%
      mutate(method = factor(method, levels = rev(method)))

    plot_obj <- ggplot(plot_data, aes(x = method, y = n, fill = method, text = paste(method, n))) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      labs(
        x = "",
        y = "Incidents"
      ) +
      theme_minimal()

    ggplotly(plot_obj, tooltip = "text")
  })

  output$age_plot <- renderPlotly({
    data <- filtered_data()

    if (nrow(data) == 0) {
      return(empty_plot("Victim age distribution"))
    }

    plot_obj <- ggplot(data, aes(x = age)) +
      geom_histogram(
        binwidth = 5,
        boundary = 0,
        closed = "left",
        fill = "#2b7a78",
        color = "white"
      ) +
      labs(
        x = "Victim age",
        y = "Incidents"
      ) +
      theme_minimal()

    ggplotly(plot_obj, tooltip = c("x", "y"))
  })

  output$location_plot <- renderPlotly({
    data <- filtered_data()

    if (nrow(data) == 0) {
      return(empty_plot("Top incident locations"))
    }

    location_data <- data %>% filter(block_label != "Unknown")

    if (nrow(location_data) == 0) {
      location_data <- data
    }

    plot_data <- location_data %>%
      count(block_label, sort = TRUE) %>%
      slice_head(n = 10) %>%
      mutate(block_label = factor(block_label, levels = rev(block_label)))

    plot_obj <- ggplot(plot_data, aes(x = block_label, y = n, fill = n, text = paste(block_label, n))) +
      geom_col(show.legend = FALSE) +
      coord_flip() +
      labs(
        x = "",
        y = "Incidents"
      ) +
      theme_minimal()

    ggplotly(plot_obj, tooltip = "text")
  })

  output$incident_table <- renderDT({
    data <- filtered_data() %>%
      transmute(
        Date = format(date, "%Y-%m-%d"),
        Year = year,
        Name = name,
        Age = age,
        Address = address,
        Method = method,
        `Case Status` = case_status,
        `CCTV` = camera_label
      )

    datatable(
      data,
      rownames = FALSE,
      filter = "top",
      options = list(pageLength = 12, scrollX = TRUE)
    )
  })

  output$download_filtered <- downloadHandler(
    filename = function() {
      "filtered_homicides.csv"
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )
}

shinyApp(ui = ui, server = server)
