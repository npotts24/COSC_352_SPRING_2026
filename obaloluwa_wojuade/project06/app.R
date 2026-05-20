suppressPackageStartupMessages({
  library(shiny)
  library(dplyr)
  library(stringr)
  library(lubridate)
  library(rvest)
  library(tidyr)
  library(plotly)
  library(DT)
  library(scales)
})

YEARS_TO_SCRAPE <- 2022:year(Sys.Date())
# Use a writable location in containers and local runs.
CACHE_FILE <- file.path(tempdir(), "homicide_cache.rds")

build_year_url <- function(year) {
  sprintf("https://chamspage.blogspot.com/%d/01/%d-baltimore-city-homicide-list.html", year, year)
}

normalize_colnames <- function(x) {
  x %>%
    str_trim() %>%
    str_to_lower() %>%
    str_replace_all("[^a-z0-9]+", "_") %>%
    str_replace_all("^_+|_+$", "")
}

promote_first_row_if_header <- function(df) {
  if (nrow(df) == 0 || ncol(df) == 0) return(df)

  first_row <- as.character(unlist(df[1, ], use.names = FALSE))
  first_row[is.na(first_row)] <- ""
  first_row_norm <- normalize_colnames(first_row)
  header_hits <- sum(str_detect(first_row_norm, "age|victim|name|date|method|camera|closed|status"), na.rm = TRUE)

  if (header_hits >= 2) {
    names(df) <- make.names(first_row_norm, unique = TRUE)
    df <- df[-1, , drop = FALSE]
  }

  df
}

extract_numeric_age <- function(text_col) {
  age <- str_extract(as.character(text_col), "\\b(1[01][0-9]|120|[1-9]?[0-9])\\b")
  suppressWarnings(as.integer(age))
}

find_column <- function(df, patterns) {
  cols <- names(df)
  idx <- which(str_detect(cols, patterns))
  if (length(idx) == 0) return(NA_character_)
  cols[idx[1]]
}

parse_homicide_tables <- function(url) {
  page <- read_html(url)
  tables <- html_elements(page, "table")

  if (length(tables) == 0) {
    stop("No HTML tables were found at the source URL.")
  }

  parsed <- lapply(seq_along(tables), function(i) {
    raw <- html_table(tables[[i]], fill = TRUE)
    raw <- promote_first_row_if_header(raw)
    names(raw) <- normalize_colnames(names(raw))
    raw$source_table_id <- i
    raw
  })

  bind_rows(parsed)
}

parse_year_data <- function(year) {
  source_url <- build_year_url(year)

  tryCatch({
    data <- parse_homicide_tables(source_url)
    data$scrape_year <- year
    data$source_url <- source_url
    data
  }, error = function(e) {
    message(sprintf("Skipping year %d (%s)", year, conditionMessage(e)))
    NULL
  })
}

standardize_yes_no_unknown <- function(x) {
  v <- str_to_lower(str_squish(as.character(x)))
  case_when(
    v %in% c("yes", "y", "true", "camera", "near camera", "cctv", "near cctv") ~ "Yes",
    v %in% c("no", "n", "false", "none", "not near camera", "no camera") ~ "No",
    is.na(v) | v == "" ~ "Unknown",
    TRUE ~ "Unknown"
  )
}

standardize_case_status <- function(x) {
  v <- str_to_lower(str_squish(as.character(x)))
  case_when(
    str_detect(v, "closed|cleared|arrest") ~ "Closed",
    str_detect(v, "open|unsolved|active|pending") ~ "Open",
    is.na(v) | v == "" ~ "Unknown",
    TRUE ~ str_to_title(v)
  )
}

clean_homicide_data <- function(raw_data) {
  if (nrow(raw_data) == 0) return(raw_data)

  age_col <- find_column(raw_data, "(^|_)age($|_)|victim_age")
  victim_col <- find_column(raw_data, "victim|name")
  date_col <- find_column(raw_data, "date|death|incident")
  method_col <- find_column(raw_data, "method|weapon|cause")
  camera_col <- find_column(raw_data, "camera|cctv")
  closed_col <- find_column(raw_data, "closed|status|clear")
  sex_col <- find_column(raw_data, "sex|gender")
  race_col <- find_column(raw_data, "race|ethnicity")
  area_col <- find_column(raw_data, "district|neighborhood|neighbourhood|zip|location|address|sector|area")

  df <- raw_data

  if (!is.na(age_col)) {
    df <- df %>% mutate(age = suppressWarnings(as.integer(.data[[age_col]])))
  } else if (!is.na(victim_col)) {
    df <- df %>% mutate(age = extract_numeric_age(.data[[victim_col]]))
  } else {
    df <- df %>% mutate(age = NA_integer_)
  }

  if (!is.na(date_col)) {
    df <- df %>% mutate(
      date_of_death = suppressWarnings(parse_date_time(
        .data[[date_col]],
        orders = c("mdy", "m/d/y", "m/d/Y", "B d, Y", "b d, Y", "Y-m-d", "Y/m/d")
      ))
    )
  } else {
    df <- df %>% mutate(date_of_death = as.POSIXct(NA))
  }

  df <- df %>% mutate(
    method = if (!is.na(method_col)) str_squish(as.character(.data[[method_col]])) else "Unknown",
    camera = if (!is.na(camera_col)) standardize_yes_no_unknown(.data[[camera_col]]) else "Unknown",
    case_status = if (!is.na(closed_col)) standardize_case_status(.data[[closed_col]]) else "Unknown",
    victim_sex = if (!is.na(sex_col)) str_to_title(str_squish(as.character(.data[[sex_col]]))) else "Unknown",
    victim_race = if (!is.na(race_col)) str_to_title(str_squish(as.character(.data[[race_col]]))) else "Unknown",
    area = if (!is.na(area_col)) str_squish(as.character(.data[[area_col]])) else "Unknown"
  )

  df <- df %>% mutate(
    age = ifelse(!is.na(age) & age >= 0 & age <= 120, as.integer(age), NA_integer_),
    date = as.Date(date_of_death),
    incident_year = ifelse(!is.na(date), year(date), scrape_year),
    incident_month_num = ifelse(!is.na(date), month(date), NA_integer_),
    incident_month = ifelse(!is.na(date), month(date, label = TRUE, abbr = TRUE), NA)
  )

  df$method[df$method == "" | is.na(df$method)] <- "Unknown"
  df$area[df$area == "" | is.na(df$area)] <- "Unknown"
  df$victim_sex[df$victim_sex == "" | is.na(df$victim_sex)] <- "Unknown"
  df$victim_race[df$victim_race == "" | is.na(df$victim_race)] <- "Unknown"

  df
}

scrape_all_years <- function(years = YEARS_TO_SCRAPE) {
  yearly_tables <- lapply(years, parse_year_data)
  raw_data <- bind_rows(yearly_tables)

  if (nrow(raw_data) == 0) {
    stop("No data could be scraped for any requested year.")
  }

  clean_homicide_data(raw_data)
}

load_homicide_data <- function(cache_path = CACHE_FILE, cache_ttl_hours = 24) {
  cache_exists <- file.exists(cache_path)
  cache_is_fresh <- FALSE

  if (cache_exists) {
    cache_age_hours <- as.numeric(difftime(Sys.time(), file.info(cache_path)$mtime, units = "hours"))
    cache_is_fresh <- is.finite(cache_age_hours) && cache_age_hours <= cache_ttl_hours
  }

  if (cache_exists && cache_is_fresh) {
    return(readRDS(cache_path))
  }

  scraped <- tryCatch(scrape_all_years(), error = function(e) {
    message("Live scrape failed: ", conditionMessage(e))
    NULL
  })

  if (!is.null(scraped) && nrow(scraped) > 0) {
    tryCatch(
      saveRDS(scraped, cache_path),
      error = function(e) {
        message("Cache write skipped: ", conditionMessage(e))
      }
    )
    return(scraped)
  }

  if (cache_exists) {
    message("Falling back to cached data.")
    return(readRDS(cache_path))
  }

  data.frame()
}

all_data <- load_homicide_data()

ui <- fluidPage(
  titlePanel("Baltimore City Police Department: Homicide Analysis Dashboard"),
  sidebarLayout(
    sidebarPanel(
      dateRangeInput("date_range", "Date range", start = Sys.Date() - 365, end = Sys.Date()),
      sliderInput("age_range", "Victim age range", min = 0, max = 120, value = c(0, 120), step = 1),
      selectizeInput("methods", "Method", choices = NULL, multiple = TRUE),
      selectizeInput("areas", "Geographic area", choices = NULL, multiple = TRUE),
      checkboxGroupInput("statuses", "Case status", choices = c("Closed", "Open", "Unknown"), selected = c("Closed", "Open", "Unknown")),
      checkboxGroupInput("camera", "Near CCTV", choices = c("Yes", "No", "Unknown"), selected = c("Yes", "No", "Unknown")),
      selectInput("sex", "Victim sex", choices = NULL, selected = "All"),
      selectInput("race", "Victim race", choices = NULL, selected = "All")
    ),
    mainPanel(
      fluidRow(
        column(3, wellPanel(h4("Total Homicides"), textOutput("total_homicides"))),
        column(3, wellPanel(h4("Clearance Rate"), textOutput("clearance_rate"))),
        column(3, wellPanel(h4("Average Victim Age"), textOutput("avg_age"))),
        column(3, wellPanel(h4("Near CCTV"), textOutput("camera_share")))
      ),
      fluidRow(
        column(6, wellPanel(h4("Most Common Method"), textOutput("top_method"))),
        column(6, wellPanel(h4("Year-Over-Year Change"), textOutput("yoy_change")))
      ),
      tabsetPanel(
        tabPanel("Trends", plotlyOutput("monthly_trend_plot", height = "420px")),
        tabPanel("Method and Area", plotlyOutput("method_status_plot", height = "360px"), plotlyOutput("area_plot", height = "360px")),
        tabPanel("Filtered Records", DTOutput("records_table"))
      )
    )
  )
)

server <- function(input, output, session) {
  data <- reactiveVal(all_data)

  observe({
    df <- data()
    req(nrow(df) > 0)

    valid_dates <- df$date[!is.na(df$date)]
    if (length(valid_dates) > 0) {
      updateDateRangeInput(session, "date_range", start = min(valid_dates), end = max(valid_dates), min = min(valid_dates), max = max(valid_dates))
    }

    valid_ages <- df$age[!is.na(df$age)]
    if (length(valid_ages) > 0) {
      updateSliderInput(session, "age_range", min = min(valid_ages), max = max(valid_ages), value = c(min(valid_ages), max(valid_ages)))
    }

    method_choices <- sort(unique(df$method))
    area_choices <- sort(unique(df$area))
    sex_choices <- c("All", sort(unique(df$victim_sex)))
    race_choices <- c("All", sort(unique(df$victim_race)))

    updateSelectizeInput(session, "methods", choices = method_choices, selected = method_choices, server = TRUE)
    updateSelectizeInput(session, "areas", choices = area_choices, selected = area_choices, server = TRUE)
    updateSelectInput(session, "sex", choices = sex_choices, selected = "All")
    updateSelectInput(session, "race", choices = race_choices, selected = "All")
  })

  filtered <- reactive({
    df <- data()
    req(nrow(df) > 0)

    out <- df

    if (!is.null(input$date_range) && length(input$date_range) == 2) {
      out <- out %>% filter(is.na(date) | (date >= as.Date(input$date_range[1]) & date <= as.Date(input$date_range[2])))
    }

    if (!is.null(input$age_range) && length(input$age_range) == 2) {
      out <- out %>% filter(is.na(age) | (age >= input$age_range[1] & age <= input$age_range[2]))
    }

    if (!is.null(input$methods) && length(input$methods) > 0) {
      out <- out %>% filter(method %in% input$methods)
    }

    if (!is.null(input$areas) && length(input$areas) > 0) {
      out <- out %>% filter(area %in% input$areas)
    }

    if (!is.null(input$statuses) && length(input$statuses) > 0) {
      out <- out %>% filter(case_status %in% input$statuses)
    }

    if (!is.null(input$camera) && length(input$camera) > 0) {
      out <- out %>% filter(camera %in% input$camera)
    }

    if (!is.null(input$sex) && input$sex != "All") {
      out <- out %>% filter(victim_sex == input$sex)
    }

    if (!is.null(input$race) && input$race != "All") {
      out <- out %>% filter(victim_race == input$race)
    }

    out
  })

  output$total_homicides <- renderText({
    n <- nrow(filtered())
    comma(n)
  })

  output$clearance_rate <- renderText({
    df <- filtered()
    known <- df %>% filter(case_status %in% c("Closed", "Open"))
    if (nrow(known) == 0) return("N/A")
    percent(mean(known$case_status == "Closed"), accuracy = 0.1)
  })

  output$avg_age <- renderText({
    df <- filtered() %>% filter(!is.na(age))
    if (nrow(df) == 0) return("N/A")
    sprintf("%.1f years", mean(df$age))
  })

  output$camera_share <- renderText({
    df <- filtered() %>% filter(camera %in% c("Yes", "No"))
    if (nrow(df) == 0) return("N/A")
    percent(mean(df$camera == "Yes"), accuracy = 0.1)
  })

  output$top_method <- renderText({
    df <- filtered()
    if (nrow(df) == 0) return("No records in current filter")
    top <- df %>% count(method, sort = TRUE) %>% slice(1)
    paste0(top$method, " (", comma(top$n), ")")
  })

  output$yoy_change <- renderText({
    df <- filtered() %>% filter(!is.na(incident_year))
    if (nrow(df) == 0) return("N/A")

    yearly <- df %>% count(incident_year, name = "homicides") %>% arrange(incident_year)
    if (nrow(yearly) < 2) return("Need at least two years in current filter")

    last <- yearly$homicides[nrow(yearly)]
    prev <- yearly$homicides[nrow(yearly) - 1]

    if (prev == 0) return("N/A")

    change <- (last - prev) / prev
    paste0(yearly$incident_year[nrow(yearly) - 1], " to ", yearly$incident_year[nrow(yearly)], ": ", percent(change, accuracy = 0.1), " (", comma(prev), " to ", comma(last), ")")
  })

  output$monthly_trend_plot <- renderPlotly({
    df <- filtered() %>% filter(!is.na(date), !is.na(incident_year), !is.na(incident_month_num))
    validate(need(nrow(df) > 0, "No records with valid dates for the current filters."))

    monthly <- df %>%
      count(incident_year, incident_month_num, name = "homicides") %>%
      complete(incident_year, incident_month_num = 1:12, fill = list(homicides = 0L)) %>%
      arrange(incident_year, incident_month_num) %>%
      mutate(month_label = month.abb[incident_month_num])

    plot_ly(
      data = monthly,
      x = ~incident_month_num,
      y = ~homicides,
      color = ~as.factor(incident_year),
      type = "scatter",
      mode = "lines+markers",
      hovertemplate = paste(
        "Year: %{color}<br>",
        "Month: %{customdata}<br>",
        "Homicides: %{y}<extra></extra>"
      ),
      customdata = ~month_label
    ) %>%
      layout(
        title = "Monthly Homicide Trend by Year",
        xaxis = list(title = "Month", tickvals = 1:12, ticktext = month.abb),
        yaxis = list(title = "Homicides")
      )
  })

  output$method_status_plot <- renderPlotly({
    df <- filtered()
    validate(need(nrow(df) > 0, "No records match the current filters."))

    plot_df <- df %>%
      count(method, case_status, name = "homicides") %>%
      group_by(method) %>%
      mutate(total_method = sum(homicides)) %>%
      ungroup() %>%
      arrange(desc(total_method)) %>%
      slice_head(n = 30)

    plot_ly(
      data = plot_df,
      x = ~reorder(method, total_method),
      y = ~homicides,
      color = ~case_status,
      type = "bar",
      hovertemplate = "Method: %{x}<br>Status: %{color}<br>Homicides: %{y}<extra></extra>"
    ) %>%
      layout(
        title = "Method by Case Status",
        xaxis = list(title = "Method", tickangle = -35),
        yaxis = list(title = "Homicides"),
        barmode = "stack"
      )
  })

  output$area_plot <- renderPlotly({
    df <- filtered()
    validate(need(nrow(df) > 0, "No records match the current filters."))

    area_df <- df %>%
      count(area, name = "homicides", sort = TRUE) %>%
      slice_head(n = 20)

    plot_ly(
      data = area_df,
      x = ~reorder(area, homicides),
      y = ~homicides,
      type = "bar",
      hovertemplate = "Area: %{x}<br>Homicides: %{y}<extra></extra>",
      marker = list(color = "#1f77b4")
    ) %>%
      layout(
        title = "Top Geographic Areas by Homicide Count",
        xaxis = list(title = "Area", tickangle = -35),
        yaxis = list(title = "Homicides")
      )
  })

  output$records_table <- renderDT({
    df <- filtered()

    if (nrow(df) == 0) {
      return(datatable(data.frame(Message = "No records match the current filters."), options = list(dom = "t"), rownames = FALSE))
    }

    display_cols <- intersect(
      c("date", "incident_year", "age", "victim_sex", "victim_race", "method", "case_status", "camera", "area", "source_url"),
      names(df)
    )

    datatable(
      df[, display_cols, drop = FALSE],
      filter = "top",
      options = list(pageLength = 10, scrollX = TRUE)
    )
  })
}

shinyApp(ui = ui, server = server)
