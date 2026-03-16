🔍 Baltimore City Homicide Analysis Dashboard

An interactive, Docker-deployed crime analysis dashboard built with R Shiny: scraping live data, visualizing multi-year homicide trends, and enabling real-time filtering for law enforcement decision-making.

Live demo: 


What This Project Does
This tool was built as a simulated contract for the Baltimore City Police Department. It pulls live homicide records directly from a public data source, parses and cleans the data programmatically, and presents it through a fully interactive browser-based dashboard — all containerized with Docker for one-command deployment.
A police commander can sit down, open a browser, and immediately answer questions like:

Are homicides increasing or decreasing year over year?
Which neighborhoods and months are highest risk?
What is the current case clearance rate?
How does victim age vary by cause of death?

 Key Features

Live web scraping : pulls 2023, 2024, and 2025 homicide data at startup using rvest; no manual data entry
Multi-year trend analysis : year-over-year comparisons across all charts
10+ interactive visualizations : bar charts, line charts, pie charts, box plots, histograms, and a live map
Real-time sidebar filters : filter by year, age range, cause of death, and sex; every chart updates instantly
Summary statistics panel :total homicides, clearance rate, average victim age, most common cause
Interactive map : color-coded incident markers (open vs. closed cases) with clickable popups
Searchable data table : full record-level exploration with column filters
Crash-proof : graceful fallback to synthetic data if scraping fails; empty filter states never crash the app
One-command Docker deployment:— run ./run_dashboard.sh and open a browser


 Tech Stack
CategoryToolsLanguageR 4.3.3DashboardShiny, shinydashboardVisualizationsPlotly, LeafletData Wranglingdplyr, lubridate, stringrWeb Scrapingrvest, httr, xml2ContainerizationDocker (rocker/r-ver:4.3.3)

 Quick Start
Requirements: Docker Desktop installed and running. That's it.
bashgit clone https://github.com/yourusername/baltimore-homicide-dashboard
cd baltimore-homicide-dashboard
chmod +x run_dashboard.sh
./run_dashboard.sh
Open your browser at http://localhost:3838

First build takes ~15 minutes (compiling R packages). Every subsequent run starts in seconds thanks to Docker layer caching.

bash# Stop the dashboard
docker stop homicide-dashboard

📁 Project Structure
├── shinyapp/
│   └── app.R              # Complete Shiny app — UI, server, and data pipeline
├── Dockerfile             # ARM64-compatible Docker image (rocker/r-ver:4.3.3)
├── run_dashboard.sh       # One-command build + launch script
└── README.md

 Technical Highlights
Web scraping pipeline : rvest scrapes HTML tables from a public blog, with dynamic column name normalization to handle inconsistencies across years. Regex-based parsing handles date formats, case status fields, and demographic data.
Reactive architecture : a single reactive() expression drives all 10+ outputs. Filters are applied once at the data layer, not per-chart, eliminating redundant computation.
Docker on Apple Silicon : rocker/shiny has no ARM64 image, so this uses rocker/r-ver with a manual Shiny launch command. leaflet is compiled from source with required geo system libraries (libgdal, libgeos, libproj) to ensure ARM64 compatibility.
Resilient design : the app ships with a synthetic fallback dataset and per-chart empty-state handling, so it never crashes regardless of network conditions or filter combinations.

 Data Source
Public homicide records from the Baltimore City Homicide blog:

https://chamspage.blogspot.com/2025/01/2025-baltimore-city-homicide-list.html
https://chamspage.blogspot.com/2024/01/2024-baltimore-city-homicide-list.html
https://chamspage.blogspot.com/2023/01/2023-baltimore-city-homicide-list.html


Geographic coordinates are approximated within Baltimore city bounds as the source does not include precise addresses.


👤 Author
Rochak Ghimire
