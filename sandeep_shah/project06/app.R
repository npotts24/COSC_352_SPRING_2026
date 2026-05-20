library(shiny)
library(shinydashboard)
library(plotly)
library(dplyr)
library(DT)

source("scraper.R")
homicide_data <- load_and_clean()

all_years   <- sort(unique(homicide_data$year))
min_year    <- min(all_years, na.rm = TRUE)
max_year    <- max(all_years, na.rm = TRUE)
all_methods <- sort(unique(homicide_data$cause))
all_methods <- all_methods[!is.na(all_methods) & all_methods != ""]

ui <- dashboardPage(
  skin = "black",
  dashboardHeader(title = "BPD Homicide Analytics", titleWidth = 300),
  dashboardSidebar(
    width = 270,
    sidebarMenu(
      menuItem("Overview",     tabName = "overview", icon = icon("chart-bar")),
      menuItem("Crime Map",    tabName = "map",      icon = icon("map")),
      menuItem("Trends",       tabName = "trends",   icon = icon("chart-line")),
      menuItem("Case Records", tabName = "records",  icon = icon("table"))
    ),
    hr(),
    div(style = "padding:0 15px;",
      h5("FILTERS", style = "color:#aaa; font-weight:700; letter-spacing:1px;"),
      sliderInput("year_range", "Year Range",
        min = min_year, max = max_year,
        value = c(min_year, max_year),
        step = 1, sep = "", ticks = FALSE),
      sliderInput("age_range", "Victim Age Range",
        min = 0, max = 100,
        value = c(0, 100),
        step = 1, ticks = FALSE),
      checkboxGroupInput("methods", "Cause of Death",
        choices  = all_methods,
        selected = all_methods),
      selectInput("case_status", "Case Status",
        choices  = c("All", "Open", "Closed (Arrest)", "Closed (No Arrest)"),
        selected = "All"),
      br(),
      actionButton("reset_filters", "Reset All Filters",
        style = "width:100%; background:#c0392b; color:white;
                 border:none; border-radius:4px; padding:8px;")
    )
  ),
  dashboardBody(
    tags$head(tags$style(HTML("
      body, .content-wrapper {
        background-color: #1a1a2e;
        font-family: 'Segoe UI', sans-serif;
      }
      .main-header .logo,
      .main-header .navbar,
      .main-sidebar { background-color: #0f0f23 !important; }
      .sidebar-menu > li > a { color: #ccc !important; }
      .sidebar-menu > li.active > a {
        background-color: #c0392b !important;
        color: white !important;
      }
      .stat-box {
        background: linear-gradient(135deg, #16213e, #0f3460);
        border: 1px solid #e94560;
        border-radius: 10px;
        padding: 16px 10px;
        margin-bottom: 15px;
        text-align: center;
      }
      .stat-number {
        font-size: 2em;
        font-weight: 800;
        color: #e94560;
      }
      .stat-label {
        font-size: 0.78em;
        color: #aaa;
        text-transform: uppercase;
        letter-spacing: 1px;
        margin-top: 4px;
      }
      .stat-sub { font-size: 0.72em; color: #7f8c8d; margin-top: 2px; }
      .chart-box {
        background: #16213e;
        border: 1px solid #0f3460;
        border-radius: 10px;
        padding: 15px;
        margin-bottom: 15px;
      }
      .chart-title {
        color: #e94560;
        font-size: 0.95em;
        font-weight: 700;
        letter-spacing: 0.5px;
        margin-bottom: 10px;
        text-transform: uppercase;
      }
    "))),
    tabItems(

      # ── OVERVIEW ──────────────────────────────────────────────────────────
      tabItem(tabName = "overview",
        fluidRow(
          column(2, div(class = "stat-box",
            div(class = "stat-number", textOutput("stat_total")),
            div(class = "stat-label", "Total Homicides"),
            div(class = "stat-sub",   textOutput("stat_period")))),
          column(2, div(class = "stat-box",
            div(class = "stat-number", textOutput("stat_clearance")),
            div(class = "stat-label", "Clearance Rate"),
            div(class = "stat-sub",   "Closed w/ Arrest"))),
          column(2, div(class = "stat-box",
            div(class = "stat-number", textOutput("stat_avg_age")),
            div(class = "stat-label", "Avg Victim Age"),
            div(class = "stat-sub",   textOutput("stat_age_range")))),
          column(2, div(class = "stat-box",
            div(class = "stat-number", textOutput("stat_top_method")),
            div(class = "stat-label", "Top Cause"),
            div(class = "stat-sub",   textOutput("stat_method_pct")))),
          column(2, div(class = "stat-box",
            div(class = "stat-number", textOutput("stat_cctv")),
            div(class = "stat-label", "Near CCTV"),
            div(class = "stat-sub",   "% of incidents"))),
          column(2, div(class = "stat-box",
            div(class = "stat-number", textOutput("stat_open")),
            div(class = "stat-label", "Open Cases"),
            div(class = "stat-sub",   "Unsolved")))
        ),
        fluidRow(
          column(8, div(class = "chart-box",
            div(class = "chart-title", "Monthly Homicide Count 2025"),
            plotlyOutput("plot_monthly", height = "360px"))),
          column(4, div(class = "chart-box",
            div(class = "chart-title", "Cause of Death"),
            plotlyOutput("plot_cause_pie", height = "360px")))
        ),
        fluidRow(
          column(6, div(class = "chart-box",
            div(class = "chart-title", "Case Status Breakdown"),
            plotlyOutput("plot_status", height = "280px"))),
          column(6, div(class = "chart-box",
            div(class = "chart-title", "Victim Age Distribution"),
            plotlyOutput("plot_age", height = "280px")))
        )
      ),

      # ── MAP ───────────────────────────────────────────────────────────────
      tabItem(tabName = "map",
        fluidRow(column(12, div(class = "chart-box",
          div(class = "chart-title", "Homicide Incident Map - Baltimore City 2025"),
          div(style = "color:#aaa; font-size:0.85em; margin-bottom:8px;",
            "Each dot represents one homicide. Color = cause of death. Use sidebar filters to update."),
          plotlyOutput("map_plot", height = "600px"))))
      ),

      # ── TRENDS ────────────────────────────────────────────────────────────
      tabItem(tabName = "trends",
        fluidRow(column(12, div(class = "chart-box",
          div(class = "chart-title", "Cumulative Homicides Over the Year"),
          plotlyOutput("plot_cumulative", height = "360px")))),
        fluidRow(
          column(6, div(class = "chart-box",
            div(class = "chart-title", "Clearance Rate by Month"),
            plotlyOutput("plot_clearance", height = "300px"))),
          column(6, div(class = "chart-box",
            div(class = "chart-title", "CCTV Camera Coverage Impact"),
            plotlyOutput("plot_cctv_chart", height = "300px")))
        )
      ),

      # ── RECORDS ───────────────────────────────────────────────────────────
      tabItem(tabName = "records",
        fluidRow(column(12, div(class = "chart-box",
          div(class = "chart-title", "Filtered Case Records"),
          DTOutput("table_records"))))
      )
    )
  )
)

server <- function(input, output, session) {

  # Reset filters
  observeEvent(input$reset_filters, {
    updateSliderInput(session, "year_range", value = c(min_year, max_year))
    updateSliderInput(session, "age_range",  value = c(0, 100))
    updateCheckboxGroupInput(session, "methods", selected = all_methods)
    updateSelectInput(session, "case_status", selected = "All")
  })

  # Reactive filtered data
  filtered <- reactive({
    df <- homicide_data
    df <- df[!is.na(df$year) &
             df$year >= input$year_range[1] &
             df$year <= input$year_range[2], ]
    df <- df[is.na(df$age) |
             (df$age >= input$age_range[1] & df$age <= input$age_range[2]), ]
    if (length(input$methods) > 0)
      df <- df[df$cause %in% input$methods, ]
    if (input$case_status != "All")
      df <- df[!is.na(df$status) & df$status == input$case_status, ]
    df
  })

  # ── Stat boxes ──────────────────────────────────────────────────────────
  output$stat_total <- renderText({
    format(nrow(filtered()), big.mark = ",")
  })
  output$stat_period <- renderText({
    paste(input$year_range[1], "to", input$year_range[2])
  })
  output$stat_clearance <- renderText({
    df <- filtered()
    if (nrow(df) == 0) return("N/A")
    n_closed <- sum(grepl("Arrest", df$status, ignore.case = TRUE), na.rm = TRUE)
    paste0(round(n_closed / nrow(df) * 100, 1), "%")
  })
  output$stat_avg_age <- renderText({
    ages <- filtered()$age[!is.na(filtered()$age)]
    if (length(ages) == 0) return("N/A")
    round(mean(ages), 1)
  })
  output$stat_age_range <- renderText({
    paste("Age:", input$age_range[1], "to", input$age_range[2])
  })
  output$stat_top_method <- renderText({
    df <- filtered()
    if (nrow(df) == 0 || all(is.na(df$cause))) return("N/A")
    names(sort(table(df$cause), decreasing = TRUE))[1]
  })
  output$stat_method_pct <- renderText({
    df <- filtered()
    if (nrow(df) == 0) return("")
    top <- names(sort(table(df$cause), decreasing = TRUE))[1]
    pct <- round(sum(df$cause == top, na.rm = TRUE) / nrow(df) * 100, 1)
    paste0(pct, "% of cases")
  })
  output$stat_cctv <- renderText({
    df <- filtered()
    if (nrow(df) == 0 || !"near_cctv" %in% names(df)) return("N/A")
    paste0(round(mean(df$near_cctv, na.rm = TRUE) * 100, 1), "%")
  })
  output$stat_open <- renderText({
    df <- filtered()
    format(sum(grepl("Open", df$status, ignore.case = TRUE), na.rm = TRUE), big.mark = ",")
  })

  # ── Monthly bar chart ────────────────────────────────────────────────────
  output$plot_monthly <- renderPlotly({
    df <- filtered()
    if (nrow(df) == 0) return(plotly_empty())
    monthly <- df %>%
      filter(!is.na(month)) %>%
      group_by(month) %>%
      summarise(count = n(), .groups = "drop")
    mn <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
    monthly$month_name <- factor(mn[monthly$month], levels = mn)
    plot_ly(monthly, x = ~month_name, y = ~count, type = "bar",
      marker = list(
        color = ~count,
        colorscale = list(c(0, "#0f3460"), c(0.5, "#e94560"), c(1, "#ffd700")),
        showscale = FALSE),
      hovertemplate = "%{x}: %{y} homicides<extra></extra>") %>%
      layout(
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font  = list(color = "#ccc"),
        xaxis = list(title = "Month", gridcolor = "#2c3e50"),
        yaxis = list(title = "Homicides", gridcolor = "#2c3e50"))
  })

  # ── Cause pie ────────────────────────────────────────────────────────────
  output$plot_cause_pie <- renderPlotly({
    df <- filtered()
    if (nrow(df) == 0) return(plotly_empty())
    cc <- df %>% count(cause) %>%
      filter(!is.na(cause), cause != "") %>%
      arrange(desc(n))
    plot_ly(cc, labels = ~cause, values = ~n, type = "pie", hole = 0.45,
      marker = list(
        colors = c("#e94560","#e67e22","#9b59b6","#1abc9c","#3498db","#95a5a6"),
        line   = list(color = "#0f0f23", width = 2)),
      textinfo      = "label+percent",
      hovertemplate = "%{label}: %{value} cases<extra></extra>") %>%
      layout(
        paper_bgcolor = "transparent",
        font   = list(color = "#ccc"),
        legend = list(orientation = "v", font = list(size = 10)),
        margin = list(t = 5, b = 5))
  })

  # ── Status bar chart ─────────────────────────────────────────────────────
  output$plot_status <- renderPlotly({
    df <- filtered()
    if (nrow(df) == 0) return(plotly_empty())
    sc <- df %>% count(status) %>% filter(!is.na(status))
    colors <- c("Open" = "#e94560",
                "Closed (Arrest)" = "#2ecc71",
                "Closed (No Arrest)" = "#f39c12")
    sc$color <- colors[sc$status]
    sc$color[is.na(sc$color)] <- "#95a5a6"
    plot_ly(sc, x = ~status, y = ~n, type = "bar",
      marker = list(color = sc$color),
      hovertemplate = "%{x}: %{y}<extra></extra>") %>%
      layout(
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font  = list(color = "#ccc"),
        xaxis = list(title = ""),
        yaxis = list(title = "Cases", gridcolor = "#2c3e50"))
  })

  # ── Age histogram ────────────────────────────────────────────────────────
  output$plot_age <- renderPlotly({
    ages <- filtered()$age[!is.na(filtered()$age)]
    if (length(ages) == 0) return(plotly_empty())
    plot_ly(x = ages, type = "histogram", nbinsx = 18,
      marker = list(color = "#e94560", line = list(color = "#0f0f23", width = 1)),
      hovertemplate = "Age %{x}: %{y} victims<extra></extra>") %>%
      layout(
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font  = list(color = "#ccc"),
        xaxis = list(title = "Victim Age", gridcolor = "#2c3e50"),
        yaxis = list(title = "Count",      gridcolor = "#2c3e50"))
  })

  # ── Map (plotly scattermapbox) ───────────────────────────────────────────
  output$map_plot <- renderPlotly({
    df <- filtered()
    df_map <- df[!is.na(df$lat) & !is.na(df$lon) &
                 df$lat > 39.1  & df$lat < 39.5 &
                 df$lon > -76.8 & df$lon < -76.4, ]
    if (nrow(df_map) == 0) return(plotly_empty())
    df_map$popup <- paste0(
      ifelse(!is.na(df_map$name), df_map$name, "Unknown"), "<br>",
      "Date: ",   ifelse(!is.na(df_map$date),   df_map$date,   "?"), "<br>",
      "Cause: ",  ifelse(!is.na(df_map$cause),  df_map$cause,  "?"), "<br>",
      "Status: ", ifelse(!is.na(df_map$status), df_map$status, "?"), "<br>",
      "Age: ",    ifelse(!is.na(df_map$age),    df_map$age,    "?"))
    plot_ly(df_map,
      lat  = ~lat, lon  = ~lon,
      type = "scattermapbox",
      mode = "markers",
      color       = ~cause,
      colors      = c("#e74c3c","#e67e22","#9b59b6","#1abc9c","#95a5a6"),
      marker      = list(size = 9, opacity = 0.85),
      text        = ~popup,
      hoverinfo   = "text") %>%
      layout(
        mapbox = list(
          style  = "carto-darkmatter",
          zoom   = 10,
          center = list(lat = 39.2904, lon = -76.6122)),
        paper_bgcolor = "transparent",
        font   = list(color = "#ccc"),
        legend = list(orientation = "h", y = -0.05),
        margin = list(t = 0, b = 0, l = 0, r = 0))
  })

  # ── Cumulative line ──────────────────────────────────────────────────────
  output$plot_cumulative <- renderPlotly({
    df <- filtered()
    if (nrow(df) == 0) return(plotly_empty())
    df_sorted <- df %>%
      filter(!is.na(date)) %>%
      arrange(date) %>%
      mutate(cumulative = row_number())
    plot_ly(df_sorted, x = ~date, y = ~cumulative,
      type = "scatter", mode = "lines",
      line = list(color = "#e94560", width = 3),
      fill = "tozeroy", fillcolor = "rgba(233,69,96,0.15)",
      hovertemplate = "Date: %{x}<br>Total: %{y}<extra></extra>") %>%
      layout(
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font  = list(color = "#ccc"),
        xaxis = list(title = "Date",             gridcolor = "#2c3e50"),
        yaxis = list(title = "Cumulative Cases", gridcolor = "#2c3e50"))
  })

  # ── Clearance by month ───────────────────────────────────────────────────
  output$plot_clearance <- renderPlotly({
    df <- filtered()
    if (nrow(df) == 0) return(plotly_empty())
    clr <- df %>%
      filter(!is.na(month)) %>%
      group_by(month) %>%
      summarise(
        total   = n(),
        cleared = sum(grepl("Arrest", status, ignore.case = TRUE), na.rm = TRUE),
        rate    = round(cleared / total * 100, 1),
        .groups = "drop")
    mn <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
    clr$month_name <- factor(mn[clr$month], levels = mn)
    plot_ly(clr, x = ~month_name, y = ~rate, type = "bar",
      marker = list(
        color     = ~rate,
        colorscale = list(c(0,"#e74c3c"), c(0.5,"#f39c12"), c(1,"#2ecc71")),
        showscale = FALSE),
      hovertemplate = "%{x}: %{y}% clearance<extra></extra>") %>%
      layout(
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font  = list(color = "#ccc"),
        xaxis = list(title = ""),
        yaxis = list(title = "Clearance Rate %", gridcolor = "#2c3e50", range = c(0, 100)))
  })

  # ── CCTV impact ──────────────────────────────────────────────────────────
  output$plot_cctv_chart <- renderPlotly({
    df <- filtered()
    if (nrow(df) == 0 || !"near_cctv" %in% names(df)) return(plotly_empty())
    cd <- df %>%
      mutate(cctv_label = ifelse(near_cctv, "Near CCTV Camera", "No CCTV Camera")) %>%
      group_by(cctv_label, cause) %>%
      summarise(count = n(), .groups = "drop")
    plot_ly(cd, x = ~cctv_label, y = ~count, color = ~cause, type = "bar",
      colors = c("#e94560","#e67e22","#9b59b6","#1abc9c","#95a5a6")) %>%
      layout(
        barmode       = "stack",
        paper_bgcolor = "transparent", plot_bgcolor = "transparent",
        font  = list(color = "#ccc"),
        xaxis = list(title = ""),
        yaxis = list(title = "Homicides", gridcolor = "#2c3e50"),
        legend = list(orientation = "h", y = -0.3))
  })

  # ── Data table ───────────────────────────────────────────────────────────
  output$table_records <- renderDT({
    df <- filtered()
    if (nrow(df) == 0)
      return(data.frame(Message = "No records match current filters"))
    show_cols <- intersect(
      c("no","date","name","age","address","cause","status","near_cctv","notes"),
      names(df))
    df_show <- df[, show_cols, drop = FALSE]
    names(df_show) <- c("No","Date","Name","Age","Address",
                        "Cause","Status","Near CCTV","Notes")[seq_along(show_cols)]
    datatable(df_show,
      options = list(
        pageLength = 15, scrollX = TRUE,
        dom = "Bfrtip", buttons = c("csv", "excel"),
        columnDefs = list(list(className = "dt-center", targets = "_all"))),
      extensions = "Buttons",
      rownames   = FALSE,
      class      = "display compact") %>%
      formatStyle(
        columns    = names(df_show),
        color      = "white",
        background = "#16213e")
  })
}

shinyApp(ui = ui, server = server)
