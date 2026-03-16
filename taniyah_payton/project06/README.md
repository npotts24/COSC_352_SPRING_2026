# Baltimore City Police Department — Homicide Analysis Dashboard

An interactive Shiny dashboard for exploring homicide trends, demographics, geographic patterns, clearance rates, and CCTV impact across Baltimore City.

---

## Quick Start

```bash
chmod +x run_dashboard.sh
./run_dashboard.sh
```

Open **http://localhost:3838** in your browser. The script waits for the health check before printing the URL.

> First build takes 5-10 min (installs R packages). Subsequent builds use Docker layer cache.

---

## File Structure

```
.
├── bpd_dashboard/
│   ├── global.R     # Data pipeline, cleaning, shared constants & palettes
│   ├── ui.R         # Dashboard layout and all controls
│   └── server.R     # All reactive logic and chart definitions
├── Dockerfile       # rocker/shiny:4.3.2, installs packages, HEALTHCHECK
├── run_dashboard.sh # One-command build, launch, and readiness wait
└── README.md
```

---

## Dashboard Features

### Sidebar Filters

| Control | Type |
|---|---|
| Year Range | Slider |
| Victim Age | Slider |
| Neighborhood | Multi-select dropdown |
| Cause of Death | Checkboxes + All/None toggle |
| Case Status | Checkboxes + All/None toggle |
| Gender | Checkboxes |
| Victim Race | Checkboxes + All/None toggle |
| CCTV Coverage | Dropdown |

All filters update every chart, KPI card, and table simultaneously.

### KPI Summary Bar

| Card | Notes |
|---|---|
| Total Homicides | Count for selected period |
| Clearance Rate | "Closed: Arrest" only — "Closed: No Arrest" excluded. Green >= 40%. |
| Avg. Victim Age | Mean with min-max range |
| Most Common Method | Top method with share % |
| Near CCTV | % and count of incidents near a camera |
| Year-over-Year | Compares last year in slider vs. prior year using year-exempt reactive |

### Tabs

**Trends** — annual count, monthly seasonality, clearance rate with 40% benchmark, day-of-week pattern

**Demographics** — method bar chart, age histogram, race/gender/status breakdowns

**Map** — clustered Leaflet map with case popups + top-15 neighborhoods bar chart

**Cross-Analysis** — clearance rate by method (color-coded), by race, and year x method stacked bar

**CCTV Analysis** — clearance rate CCTV vs. no-CCTV, coverage by neighborhood, dual time-series

**Case Records** — paginated DT table with column filters, CSV/Excel export, status color coding

---

## Correctness Notes

- **Clearance rate** uses `status == "Closed: Arrest"` exactly. The old `grepl("Arrest", status)` pattern incorrectly matched "Closed: No Arrest" and is fixed.
- **Year-over-Year KPI** uses a separate `filtered_no_year()` reactive so the prior year is always available regardless of the year slider.
- **Zero-result guard** — alert banner shown instead of crash; all charts return `plotly_empty()`.

---

## Requirements

- Docker (any recent version)
- Port 3838 free on the host
