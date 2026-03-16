server <- function(input, output, session) {

  # ── "Select All / None" toggles ────────────────────────────────────────────
  observeEvent(input$method_all,  updateCheckboxGroupInput(session, "method_filter",  selected = ALL_METHODS))
  observeEvent(input$method_none, updateCheckboxGroupInput(session, "method_filter",  selected = character(0)))
  observeEvent(input$status_all,  updateCheckboxGroupInput(session, "status_filter",  selected = ALL_STATUSES))
  observeEvent(input$status_none, updateCheckboxGroupInput(session, "status_filter",  selected = character(0)))
  observeEvent(input$race_all,    updateCheckboxGroupInput(session, "race_filter",    selected = ALL_RACES))
  observeEvent(input$race_none,   updateCheckboxGroupInput(session, "race_filter",    selected = character(0)))

  # ── Core reactive: single filtered dataset ──────────────────────────────────
  filtered <- reactive({
    d <- homicide_data

    d <- d |> dplyr::filter(year >= input$year_range[1],
                             year <= input$year_range[2])

    d <- d |> dplyr::filter(is.na(age) |
                               (age >= input$age_range[1] & age <= input$age_range[2]))

    if (length(input$gender_filter) > 0)
      d <- d |> dplyr::filter(gender %in% input$gender_filter)

    if (length(input$method_filter) > 0)
      d <- d |> dplyr::filter(method %in% input$method_filter)

    if (length(input$status_filter) > 0)
      d <- d |> dplyr::filter(status %in% input$status_filter)

    if (length(input$race_filter) > 0)
      d <- d |> dplyr::filter(race %in% input$race_filter)

    if (!is.null(input$nbhd_filter) && length(input$nbhd_filter) > 0 &&
        any(nchar(input$nbhd_filter) > 0))
      d <- d |> dplyr::filter(neighborhood %in% input$nbhd_filter)

    if (input$cctv_filter == "yes")
      d <- d |> dplyr::filter(cctv_nearby == TRUE)
    else if (input$cctv_filter == "no")
      d <- d |> dplyr::filter(cctv_nearby == FALSE)

    d
  })

  # ── YoY uses UNFILTERED data on the year dimension ─────────────────────────
  # Apply every filter EXCEPT year_range so the comparison is always valid.
  filtered_no_year <- reactive({
    d <- homicide_data

    d <- d |> dplyr::filter(is.na(age) |
                               (age >= input$age_range[1] & age <= input$age_range[2]))

    if (length(input$gender_filter) > 0)
      d <- d |> dplyr::filter(gender %in% input$gender_filter)

    if (length(input$method_filter) > 0)
      d <- d |> dplyr::filter(method %in% input$method_filter)

    if (length(input$status_filter) > 0)
      d <- d |> dplyr::filter(status %in% input$status_filter)

    if (length(input$race_filter) > 0)
      d <- d |> dplyr::filter(race %in% input$race_filter)

    if (!is.null(input$nbhd_filter) && length(input$nbhd_filter) > 0 &&
        any(nchar(input$nbhd_filter) > 0))
      d <- d |> dplyr::filter(neighborhood %in% input$nbhd_filter)

    if (input$cctv_filter == "yes")
      d <- d |> dplyr::filter(cctv_nearby == TRUE)
    else if (input$cctv_filter == "no")
      d <- d |> dplyr::filter(cctv_nearby == FALSE)

    d
  })

  # ── Zero-results warning ────────────────────────────────────────────────────
  output$zero_warning <- renderUI({
    if (nrow(filtered()) == 0)
      tags$div(class = "alert-banner",
               icon("exclamation-triangle"), " ",
               "No records match the current filters. Adjust your selections.")
  })

  # ── KPI helpers ─────────────────────────────────────────────────────────────
  make_kpi <- function(value, label, sub = NULL,
                       color = BPD_BLUE, border = BPD_GOLD) {
    tags$div(class = "kpi-card",
             style = paste0("border-top-color:", border, ";"),
             tags$div(class = "kpi-value", style = paste0("color:", color), value),
             tags$div(class = "kpi-label", label),
             if (!is.null(sub)) tags$div(class = "kpi-sub", sub)
    )
  }

  output$kpi_total <- renderUI({
    n <- nrow(filtered())
    make_kpi(format(n, big.mark = ","), "Total Homicides",
             paste(input$year_range[1], "\u2013", input$year_range[2]))
  })

  output$kpi_clearance <- renderUI({
    d <- filtered()
    if (nrow(d) == 0) return(make_kpi("\u2014", "Clearance Rate"))
    # cleared column == (status == "Closed: Arrest") — set in global.R
    rate    <- mean(d$cleared, na.rm = TRUE)
    n_clear <- sum(d$cleared, na.rm = TRUE)
    col     <- if (rate >= 0.40) BPD_GREEN else BPD_RED
    make_kpi(paste0(round(rate * 100, 1), "%"), "Clearance Rate",
             paste(n_clear, "arrests /", nrow(d), "cases"), col)
  })

  output$kpi_avg_age <- renderUI({
    ages <- filtered()$age
    ages <- ages[!is.na(ages)]
    if (length(ages) == 0) return(make_kpi("\u2014", "Avg. Victim Age"))
    make_kpi(round(mean(ages), 1), "Avg. Victim Age",
             paste0("Range: ", min(ages), "\u2013", max(ages), " yrs"))
  })

  output$kpi_top_method <- renderUI({
    d <- filtered()
    if (nrow(d) == 0) return(make_kpi("\u2014", "Top Method"))
    top <- names(sort(table(d$method), decreasing = TRUE))[1]
    pct <- round(mean(d$method == top, na.rm = TRUE) * 100, 1)
    make_kpi(top, "Most Common Method", paste0(pct, "% of incidents"), BPD_BLUE, BPD_RED)
  })

  output$kpi_cctv <- renderUI({
    d <- filtered()
    if (nrow(d) == 0) return(make_kpi("\u2014", "Near CCTV"))
    pct <- round(mean(d$cctv_nearby == TRUE, na.rm = TRUE) * 100, 1)
    make_kpi(paste0(pct, "%"), "Near CCTV Camera",
             paste(sum(d$cctv_nearby == TRUE, na.rm = TRUE), "incidents"))
  })

  output$kpi_yoy <- renderUI({
    # Uses year-unfiltered reactive so prior year is always visible
    d    <- filtered_no_year()
    cur_yr  <- input$year_range[2]
    prev_yr <- cur_yr - 1
    cur  <- nrow(d |> dplyr::filter(year == cur_yr))
    prev <- nrow(d |> dplyr::filter(year == prev_yr))
    if (prev == 0) return(make_kpi("\u2014", paste("YoY", cur_yr)))
    chg   <- round((cur - prev) / prev * 100, 1)
    arrow <- if (chg <= 0) "\u25bc" else "\u25b2"
    col   <- if (chg <= 0) BPD_GREEN else BPD_RED
    make_kpi(paste0(arrow, " ", abs(chg), "%"),
             paste("YoY Change", cur_yr),
             paste(cur, "vs.", prev, "prior yr"), col)
  })

  # ══════════════════════════════════════════════════════════════════════════
  # TAB 1 — TRENDS
  # ══════════════════════════════════════════════════════════════════════════

  output$trend_annual <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    yr <- d |>
      dplyr::group_by(year) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop")

    plot_ly(yr, x = ~year, y = ~count,
            type = "scatter", mode = "lines+markers",
            line   = list(color = BPD_BLUE, width = 3),
            marker = list(color = BPD_BLUE, size = 8),
            hovertemplate = "<b>%{x}</b><br>Homicides: %{y}<extra></extra>") |>
      layout(xaxis = list(title = "Year", dtick = 1, showgrid = FALSE),
             yaxis = list(title = "Homicides", gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$trend_monthly <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    mo <- d |>
      dplyr::group_by(month_num) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
      dplyr::mutate(month_abbr = month.abb[month_num])

    plot_ly(mo, x = ~month_abbr, y = ~count, type = "bar",
            marker = list(color = BPD_BLUE),
            hovertemplate = "<b>%{x}</b>: %{y}<extra></extra>") |>
      layout(xaxis = list(title = "", categoryorder = "array",
                          categoryarray = month.abb),
             yaxis = list(title = "Homicides", gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$trend_clearance <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    yr <- d |>
      dplyr::group_by(year) |>
      dplyr::summarise(
        total   = dplyr::n(),
        cleared = sum(cleared, na.rm = TRUE),
        rate    = cleared / total * 100,
        .groups = "drop"
      )

    plot_ly(yr) |>
      add_trace(x = ~year, y = ~rate,
                type = "scatter", mode = "lines+markers",
                name = "Clearance rate",
                line   = list(color = BPD_GREEN, width = 3),
                marker = list(color = BPD_GREEN, size = 8),
                hovertemplate = "<b>%{x}</b><br>Clearance: %{y:.1f}%<extra></extra>") |>
      add_segments(x = ~min(year), xend = ~max(year),
                   y = 40, yend = 40,
                   line = list(color = BPD_RED, dash = "dot", width = 2),
                   name = "40% benchmark", inherit = FALSE) |>
      layout(xaxis  = list(title = "Year", dtick = 1, showgrid = FALSE),
             yaxis  = list(title = "Clearance Rate (%)", range = c(0, 100),
                           gridcolor = "#e5e7eb"),
             legend = list(orientation = "h", x = 0, y = -0.25),
             do.call(layout, plotly_base()))
  })

  output$trend_dow <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    dow_order <- c("Sunday","Monday","Tuesday","Wednesday",
                   "Thursday","Friday","Saturday")
    dow <- d |>
      dplyr::group_by(day_of_week) |>
      dplyr::summarise(count = dplyr::n(), .groups = "drop") |>
      dplyr::mutate(day_of_week = factor(as.character(day_of_week),
                                          levels = dow_order)) |>
      dplyr::arrange(day_of_week)

    plot_ly(dow, x = ~day_of_week, y = ~count, type = "bar",
            marker = list(color = BPD_GOLD),
            hovertemplate = "<b>%{x}</b>: %{y}<extra></extra>") |>
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Homicides", gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  # ══════════════════════════════════════════════════════════════════════════
  # TAB 2 — DEMOGRAPHICS
  # ══════════════════════════════════════════════════════════════════════════

  output$demo_method <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    mdf <- d |> dplyr::count(method, sort = TRUE)
    cols <- unname(METHOD_COLORS[mdf$method])
    cols[is.na(cols)] <- "#9CA3AF"

    plot_ly(mdf, x = ~reorder(method, n), y = ~n, type = "bar",
            marker = list(color = cols),
            hovertemplate = "<b>%{x}</b>: %{y}<extra></extra>") |>
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Homicides", gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$demo_age <- renderPlotly({
    ages <- filtered()$age |> (\(x) x[!is.na(x)])()
    if (length(ages) == 0) return(plotly_empty())

    plot_ly(x = ages, type = "histogram", nbinsx = 20,
            marker = list(color = BPD_BLUE,
                          line  = list(color = "white", width = 1)),
            hovertemplate = "Age %{x}<br>Count: %{y}<extra></extra>") |>
      layout(xaxis = list(title = "Victim Age"),
             yaxis = list(title = "Count", gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$demo_race <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    rdf <- d |> dplyr::count(race, sort = TRUE)
    plot_ly(rdf, labels = ~race, values = ~n, type = "pie",
            marker    = list(colors = c(BPD_BLUE, BPD_GOLD, BPD_GREEN,
                                        BPD_RED,  "#8B5CF6","#6B7280")),
            textinfo  = "percent+label",
            hovertemplate = "<b>%{label}</b><br>%{value} (%{percent})<extra></extra>") |>
      layout(showlegend = FALSE, margin = list(t=5,b=5),
             do.call(layout, plotly_base()))
  })

  output$demo_gender <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    gdf <- d |> dplyr::count(gender)
    plot_ly(gdf, labels = ~gender, values = ~n, type = "pie",
            marker = list(colors = c(BPD_BLUE, BPD_GOLD, "#9CA3AF")),
            textinfo = "percent+label",
            hovertemplate = "<b>%{label}</b><br>%{value}<extra></extra>") |>
      layout(showlegend = FALSE, margin = list(t=5,b=5),
             do.call(layout, plotly_base()))
  })

  output$demo_status <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    sdf  <- d |> dplyr::count(status, sort = TRUE)
    cols <- unname(STATUS_COLORS[sdf$status])
    cols[is.na(cols)] <- "#9CA3AF"

    plot_ly(sdf, x = ~reorder(status, n), y = ~n, type = "bar",
            marker = list(color = cols),
            hovertemplate = "<b>%{x}</b>: %{y}<extra></extra>") |>
      layout(xaxis = list(title = "", tickangle = -30),
             yaxis = list(title = "Cases", gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  # ══════════════════════════════════════════════════════════════════════════
  # TAB 3 — MAP
  # ══════════════════════════════════════════════════════════════════════════

  output$incident_map <- renderLeaflet({
    leaflet() |>
      addProviderTiles(providers$CartoDB.Positron) |>
      setView(lng = -76.616, lat = 39.299, zoom = 12)
  })

  observe({
    d <- filtered() |> dplyr::filter(!is.na(lat), !is.na(lon))
    pal <- colorFactor(
      palette = unname(METHOD_COLORS),
      levels  = names(METHOD_COLORS),
      na.color = "#9CA3AF"
    )
    leafletProxy("incident_map") |>
      clearMarkerClusters() |>
      clearMarkers() |>
      clearControls() |>
      addCircleMarkers(
        data        = d,
        lng         = ~lon, lat = ~lat,
        radius      = 5,
        color       = ~pal(method),
        fillOpacity = 0.75,
        stroke      = FALSE,
        popup = ~paste0(
          "<b>", ifelse(is.na(name), "Unknown", name), "</b><br>",
          format(date, "%B %d, %Y"), "<br>",
          "<b>Method:</b> ", method, "<br>",
          "<b>Age:</b> ", ifelse(is.na(age), "Unknown", as.character(age)), "<br>",
          "<b>Neighborhood:</b> ", neighborhood, "<br>",
          "<b>Status:</b> <span style='color:",
          ifelse(cleared, "#10B981", "#EF4444"), "'>", status, "</span>"
        ),
        clusterOptions = markerClusterOptions(maxClusterRadius = 45)
      ) |>
      addLegend("bottomright", pal = pal, values = d$method,
                title = "Cause of Death", opacity = 0.85)
  })

  output$map_nbhd_bar <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    nb <- d |>
      dplyr::count(neighborhood, sort = TRUE) |>
      head(15)

    plot_ly(nb, x = ~n, y = ~reorder(neighborhood, n),
            type = "bar", orientation = "h",
            marker = list(color = BPD_BLUE),
            hovertemplate = "<b>%{y}</b>: %{x}<extra></extra>") |>
      layout(xaxis  = list(title = "Homicides", gridcolor = "#e5e7eb"),
             yaxis  = list(title = ""),
             margin = list(l = 150, t = 10, b = 40, r = 20),
             do.call(layout, plotly_base()))
  })

  # ══════════════════════════════════════════════════════════════════════════
  # TAB 4 — CROSS-ANALYSIS
  # ══════════════════════════════════════════════════════════════════════════

  output$cross_method_status <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    ms <- d |>
      dplyr::group_by(method) |>
      dplyr::summarise(
        total      = dplyr::n(),
        n_cleared  = sum(cleared, na.rm = TRUE),
        rate       = round(n_cleared / total * 100, 1),
        .groups    = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(total))

    plot_ly(ms, x = ~method, y = ~rate, type = "bar",
            marker = list(color = ~rate,
                          colorscale = list(c(0,"#EF4444"), c(1,"#10B981")),
                          showscale  = FALSE),
            text  = ~paste0(rate, "%"),
            textposition = "outside",
            hovertemplate = paste0(
              "<b>%{x}</b><br>",
              "Clearance: %{y:.1f}%<br>",
              "Total cases: ", ms$total,
              "<extra></extra>")) |>
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Clearance Rate (%)", range = c(0, 105),
                          gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$cross_race_status <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    rs <- d |>
      dplyr::group_by(race) |>
      dplyr::summarise(
        total     = dplyr::n(),
        n_cleared = sum(cleared, na.rm = TRUE),
        rate      = round(n_cleared / total * 100, 1),
        .groups   = "drop"
      ) |>
      dplyr::filter(total >= 5) |>
      dplyr::arrange(dplyr::desc(rate))

    plot_ly(rs, x = ~reorder(race, rate), y = ~rate, type = "bar",
            marker = list(color = BPD_BLUE),
            hovertemplate = "<b>%{x}</b><br>Clearance: %{y:.1f}%<extra></extra>") |>
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Clearance Rate (%)", range = c(0, 100),
                          gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$cross_year_method <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    ym <- d |>
      dplyr::count(year, method) |>
      tidyr::pivot_wider(names_from = method, values_from = n, values_fill = 0)

    methods_present <- setdiff(names(ym), "year")
    p <- plot_ly()
    for (m in methods_present) {
      col <- if (!is.na(METHOD_COLORS[m])) METHOD_COLORS[m] else "#9CA3AF"
      p <- p |> add_trace(data = ym, x = ~year, y = as.formula(paste0("~`",m,"`")),
                           name = m, type = "bar",
                           marker = list(color = col))
    }
    p |> layout(barmode = "stack",
                xaxis   = list(title = "Year", dtick = 1, showgrid = FALSE),
                yaxis   = list(title = "Homicides", gridcolor = "#e5e7eb"),
                legend  = list(orientation = "h", x = 0, y = -0.25),
                do.call(layout, plotly_base()))
  })

  # ══════════════════════════════════════════════════════════════════════════
  # TAB 5 — CCTV
  # ══════════════════════════════════════════════════════════════════════════

  output$cctv_clearance_bar <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    cdf <- d |>
      dplyr::mutate(cctv_label = ifelse(cctv_nearby, "Near CCTV", "No CCTV")) |>
      dplyr::group_by(cctv_label) |>
      dplyr::summarise(
        total     = dplyr::n(),
        n_cleared = sum(cleared, na.rm = TRUE),
        rate      = round(n_cleared / total * 100, 1),
        .groups   = "drop"
      )

    plot_ly(cdf, x = ~cctv_label, y = ~rate, type = "bar",
            marker = list(color = c("#10B981","#EF4444")),
            text  = ~paste0(rate, "%"),
            textposition = "outside",
            hovertemplate = "<b>%{x}</b><br>Clearance: %{y:.1f}%<extra></extra>") |>
      layout(xaxis = list(title = ""),
             yaxis = list(title = "Clearance Rate (%)", range = c(0, 100),
                          gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$cctv_nbhd <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    nc <- d |>
      dplyr::group_by(neighborhood) |>
      dplyr::summarise(
        total    = dplyr::n(),
        cctv_pct = round(mean(cctv_nearby == TRUE, na.rm = TRUE) * 100, 1),
        .groups  = "drop"
      ) |>
      dplyr::filter(total >= 5) |>
      dplyr::arrange(dplyr::desc(cctv_pct)) |>
      head(12)

    plot_ly(nc, x = ~reorder(neighborhood, cctv_pct), y = ~cctv_pct,
            type = "bar", marker = list(color = "#3B82F6"),
            hovertemplate = "<b>%{x}</b>: %{y}% near CCTV<extra></extra>") |>
      layout(xaxis = list(title = "", tickangle = -40),
             yaxis = list(title = "% Near CCTV", gridcolor = "#e5e7eb"),
             do.call(layout, plotly_base()))
  })

  output$cctv_trend <- renderPlotly({
    d <- filtered()
    if (nrow(d) == 0) return(plotly_empty())

    ct <- d |>
      dplyr::group_by(year) |>
      dplyr::summarise(
        rate_cctv    = round(mean(cleared[cctv_nearby == TRUE],  na.rm = TRUE) * 100, 1),
        rate_no_cctv = round(mean(cleared[cctv_nearby != TRUE],  na.rm = TRUE) * 100, 1),
        .groups = "drop"
      )

    plot_ly(ct) |>
      add_trace(x = ~year, y = ~rate_cctv, name = "Near CCTV",
                type = "scatter", mode = "lines+markers",
                line = list(color = BPD_GREEN, width = 2),
                marker = list(color = BPD_GREEN),
                hovertemplate = "<b>%{x}</b> Near CCTV: %{y:.1f}%<extra></extra>") |>
      add_trace(x = ~year, y = ~rate_no_cctv, name = "No CCTV",
                type = "scatter", mode = "lines+markers",
                line = list(color = BPD_RED, width = 2),
                marker = list(color = BPD_RED),
                hovertemplate = "<b>%{x}</b> No CCTV: %{y:.1f}%<extra></extra>") |>
      layout(xaxis  = list(title = "Year", dtick = 1, showgrid = FALSE),
             yaxis  = list(title = "Clearance Rate (%)", range = c(0, 100),
                           gridcolor = "#e5e7eb"),
             legend = list(orientation = "h", x = 0, y = -0.25),
             do.call(layout, plotly_base()))
  })

  # ══════════════════════════════════════════════════════════════════════════
  # TAB 6 — DATA TABLE
  # ══════════════════════════════════════════════════════════════════════════

  output$case_table <- renderDT({
    d <- filtered() |>
      dplyr::select(dplyr::any_of(
        c("id","date","name","age","race","gender",
          "neighborhood","method","status","cctv_nearby","cleared")
      )) |>
      dplyr::rename_with(~ stringr::str_to_title(stringr::str_replace_all(., "_", " ")))

    DT::datatable(
      d,
      filter   = "top",
      rownames = FALSE,
      extensions = "Buttons",
      options  = list(
        pageLength = 15,
        scrollX    = TRUE,
        dom        = "Bfrtip",
        buttons    = c("csv", "excel"),
        columnDefs = list(list(className = "dt-center", targets = "_all"))
      ),
      class = "stripe hover compact"
    ) |>
      DT::formatStyle(
        "Status",
        backgroundColor = DT::styleEqual(
          c("Closed: Arrest","Open","Closed: No Arrest","Active Investigation"),
          c("#d1fae5","#fef3c7","#fee2e2","#dbeafe")
        )
      )
  })
}
