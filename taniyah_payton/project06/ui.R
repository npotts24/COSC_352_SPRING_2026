library(shiny)
library(shinydashboard)
library(plotly)
library(leaflet)
library(DT)

# ── Brand colors ──────────────────────────────────────────────────────────────
bpd_blue  <- "#003087"
bpd_gold  <- "#FFB81C"
bpd_red   <- "#C8102E"

ui <- dashboardPage(
  skin = "blue",

  # ── Header ─────────────────────────────────────────────────────────────────
  dashboardHeader(
    title = tags$span(
      style = "font-weight:700; letter-spacing:0.5px;",
      "BPD Homicide Analysis"
    ),
    titleWidth = 300
  ),

  # ── Sidebar ────────────────────────────────────────────────────────────────
  dashboardSidebar(
    width = 280,

    tags$div(
      style = paste0("padding:10px 15px 4px; background:#1a2744;",
                     " color:#aab4c4; font-size:11px;",
                     " text-transform:uppercase; letter-spacing:1px;"),
      "Filter Controls"
    ),

    # Year range
    sliderInput("year_range", "Year Range",
                min  = MIN_YEAR, max = MAX_YEAR,
                value = c(max(MIN_YEAR, MAX_YEAR - 4), MAX_YEAR),
                step = 1, sep = ""),

    # Age range
    sliderInput("age_range", "Victim Age",
                min = 0, max = 85, value = c(0, 85), step = 1),

    # Neighborhood selector
    selectizeInput("nbhd_filter", "Neighborhood",
                   choices  = c("All Neighborhoods" = "", ALL_NEIGHBORHOODS),
                   selected = "",
                   multiple = TRUE,
                   options  = list(placeholder = "All neighborhoods")),

    # Cause of death
    div(style = "padding:0 15px 0;",
        tags$label("Cause of Death",
                   style = "font-weight:400; font-size:14px; color:#b8c2cc;"),
        actionLink("method_all",   "All",   style = "font-size:11px; margin-left:8px;"),
        actionLink("method_none",  "None",  style = "font-size:11px; margin-left:4px;")
    ),
    checkboxGroupInput("method_filter", label = NULL,
                       choices  = ALL_METHODS,
                       selected = ALL_METHODS),

    # Case status
    div(style = "padding:0 15px 0;",
        tags$label("Case Status",
                   style = "font-weight:400; font-size:14px; color:#b8c2cc;"),
        actionLink("status_all",  "All",  style = "font-size:11px; margin-left:8px;"),
        actionLink("status_none", "None", style = "font-size:11px; margin-left:4px;")
    ),
    checkboxGroupInput("status_filter", label = NULL,
                       choices  = ALL_STATUSES,
                       selected = ALL_STATUSES),

    # Gender
    checkboxGroupInput("gender_filter", "Gender",
                       choices  = ALL_GENDERS,
                       selected = ALL_GENDERS),

    # Race
    div(style = "padding:0 15px 0;",
        tags$label("Victim Race",
                   style = "font-weight:400; font-size:14px; color:#b8c2cc;"),
        actionLink("race_all",  "All",  style = "font-size:11px; margin-left:8px;"),
        actionLink("race_none", "None", style = "font-size:11px; margin-left:4px;")
    ),
    checkboxGroupInput("race_filter", label = NULL,
                       choices  = ALL_RACES,
                       selected = ALL_RACES),

    # CCTV
    selectInput("cctv_filter", "CCTV Coverage",
                choices  = c("All Incidents"    = "all",
                             "Near CCTV Camera" = "yes",
                             "No CCTV Nearby"   = "no"),
                selected = "all"),

    tags$hr(style = "border-color:#2d3f5e; margin:8px 0;"),
    tags$div(
      style = "padding:0 15px 10px; font-size:11px; color:#7a8a9a;",
      "Data: Baltimore Sun Homicide Tracker",
      tags$br(),
      paste("Last updated:", format(Sys.Date(), "%b %d, %Y"))
    )
  ),

  # ── Body ───────────────────────────────────────────────────────────────────
  dashboardBody(
    tags$head(
      tags$style(HTML(sprintf("
        body, .content-wrapper { background-color:#f0f4f8; }
        .box { border-radius:6px; box-shadow:0 2px 8px rgba(0,0,0,.08); }
        .box-header { border-bottom:2px solid %s; }
        .skin-blue .main-header .logo { background-color:%s; font-weight:700; }
        .skin-blue .main-header .navbar { background-color:%s; }
        .skin-blue .main-sidebar { background-color:#12233d; }
        .skin-blue .sidebar-menu>li.active>a,
        .skin-blue .sidebar-menu>li:hover>a {
          background-color:#1a2f52; border-left-color:%s; }
        .skin-blue .sidebar a { color:#b8c2cc !important; }
        .irs--shiny .irs-bar { background:%s; border-color:%s; }
        .irs--shiny .irs-handle { background:%s; border-color:%s; }

        /* KPI cards */
        .kpi-card { background:#fff; border-radius:8px; padding:14px 18px;
                    box-shadow:0 2px 8px rgba(0,0,0,.08); text-align:center;
                    border-top:3px solid %s; }
        .kpi-value { font-size:28px; font-weight:700; line-height:1; color:%s; }
        .kpi-label { font-size:11px; color:#6b7280; text-transform:uppercase;
                     letter-spacing:.5px; margin-top:4px; }
        .kpi-sub   { font-size:12px; color:#374151; margin-top:3px; }

        .alert-banner { background:#fff3cd; border-left:4px solid %s;
                        padding:10px 15px; border-radius:4px; margin-bottom:12px;
                        font-size:13px; color:#856404; }
        .nav-tabs-custom>.nav-tabs>li.active>a { border-top-color:%s; }
        .sidebar-toggle { display:none !important; }
      ",
      bpd_gold, bpd_blue, bpd_blue, bpd_gold,
      bpd_blue, bpd_blue, bpd_blue, bpd_blue,
      bpd_gold, bpd_blue, bpd_gold, bpd_blue)))
    ),

    # ── KPI row ──────────────────────────────────────────────────────────────
    fluidRow(
      column(2, uiOutput("kpi_total")),
      column(2, uiOutput("kpi_clearance")),
      column(2, uiOutput("kpi_avg_age")),
      column(2, uiOutput("kpi_top_method")),
      column(2, uiOutput("kpi_cctv")),
      column(2, uiOutput("kpi_yoy"))
    ),

    tags$div(style = "height:10px;"),
    uiOutput("zero_warning"),

    # ── Tabs ─────────────────────────────────────────────────────────────────
    tabBox(
      width = 12, id = "main_tabs",

      # 1 — Trends
      tabPanel(
        title = tags$span(icon("chart-line"), " Trends"),
        fluidRow(
          box(width = 8, title = "Homicides Over Time",
              status = "primary", solidHeader = TRUE,
              plotlyOutput("trend_annual", height = 320)),
          box(width = 4, title = "Monthly Seasonality",
              status = "primary", solidHeader = TRUE,
              plotlyOutput("trend_monthly", height = 320))
        ),
        fluidRow(
          box(width = 6, title = "Clearance Rate by Year (40% benchmark)",
              status = "warning", solidHeader = TRUE,
              plotlyOutput("trend_clearance", height = 280)),
          box(width = 6, title = "Day of Week Pattern",
              status = "warning", solidHeader = TRUE,
              plotlyOutput("trend_dow", height = 280))
        )
      ),

      # 2 — Demographics
      tabPanel(
        title = tags$span(icon("users"), " Demographics"),
        fluidRow(
          box(width = 6, title = "Cause of Death",
              status = "danger", solidHeader = TRUE,
              plotlyOutput("demo_method", height = 300)),
          box(width = 6, title = "Victim Age Distribution",
              status = "danger", solidHeader = TRUE,
              plotlyOutput("demo_age", height = 300))
        ),
        fluidRow(
          box(width = 4, title = "By Race",
              status = "info", solidHeader = TRUE,
              plotlyOutput("demo_race", height = 280)),
          box(width = 4, title = "By Gender",
              status = "info", solidHeader = TRUE,
              plotlyOutput("demo_gender", height = 280)),
          box(width = 4, title = "Case Status",
              status = "info", solidHeader = TRUE,
              plotlyOutput("demo_status", height = 280))
        )
      ),

      # 3 — Map
      tabPanel(
        title = tags$span(icon("map-marker-alt"), " Map"),
        fluidRow(
          box(width = 8, title = "Incident Map — Baltimore City",
              status = "primary", solidHeader = TRUE,
              leafletOutput("incident_map", height = 520)),
          box(width = 4, title = "Top 15 Neighborhoods by Volume",
              status = "primary", solidHeader = TRUE,
              plotlyOutput("map_nbhd_bar", height = 520))
        )
      ),

      # 4 — Method × Status cross-tab
      tabPanel(
        title = tags$span(icon("table"), " Cross-Analysis"),
        fluidRow(
          box(width = 7, title = "Clearance Rate by Cause of Death",
              status = "success", solidHeader = TRUE,
              plotlyOutput("cross_method_status", height = 320)),
          box(width = 5, title = "Clearance Rate by Race",
              status = "success", solidHeader = TRUE,
              plotlyOutput("cross_race_status", height = 320))
        ),
        fluidRow(
          box(width = 12, title = "Homicides by Year and Cause of Death (stacked)",
              status = "success", solidHeader = TRUE,
              plotlyOutput("cross_year_method", height = 280))
        )
      ),

      # 5 — CCTV
      tabPanel(
        title = tags$span(icon("video"), " CCTV Analysis"),
        fluidRow(
          box(width = 6, title = "Clearance Rate: Near CCTV vs. No CCTV",
              status = "primary", solidHeader = TRUE,
              plotlyOutput("cctv_clearance_bar", height = 300)),
          box(width = 6, title = "Top Neighborhoods by CCTV Coverage %",
              status = "primary", solidHeader = TRUE,
              plotlyOutput("cctv_nbhd", height = 300))
        ),
        fluidRow(
          box(width = 12,
              title = "Clearance Rate Over Time: CCTV vs. No CCTV",
              status = "primary", solidHeader = TRUE,
              plotlyOutput("cctv_trend", height = 280))
        )
      ),

      # 6 — Data Table
      tabPanel(
        title = tags$span(icon("database"), " Case Records"),
        box(width = 12, title = "Case Records",
            status = "primary", solidHeader = TRUE,
            DTOutput("case_table"))
      )
    )
  )
)
