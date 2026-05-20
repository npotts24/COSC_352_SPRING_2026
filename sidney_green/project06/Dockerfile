FROM rocker/shiny:latest

# 1. Install Linux system libraries that R packages need to compile
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Install the R packages
# Adding 'remotes' can sometimes help with installation stability
RUN R -e "install.packages(c('rvest', 'dplyr', 'lubridate', 'plotly', 'DT', 'leaflet'), repos='https://cran.rstudio.com/')"

# 3. Copy your specific files
COPY app.R /srv/shiny-server/
COPY scrape.R /srv/shiny-server/

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/app.R', port=3838, host='0.0.0.0')"]