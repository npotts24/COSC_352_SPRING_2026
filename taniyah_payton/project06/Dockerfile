FROM rocker/shiny:4.3.2

# System dependencies for R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install all required R packages in one layer for caching efficiency
RUN R -e "install.packages(c( \
    'shiny', \
    'shinydashboard', \
    'plotly', \
    'leaflet', \
    'DT', \
    'dplyr', \
    'lubridate', \
    'rvest', \
    'httr', \
    'stringr', \
    'tidyr' \
  ), repos='https://cran.rstudio.com/', dependencies=TRUE)"

# Copy the app files
COPY bpd_dashboard/ /srv/shiny-server/bpd/

# Shiny Server config: serve app from root
RUN printf 'run_as shiny;\nserver {\n  listen 3838;\n  location / {\n    app_dir /srv/shiny-server/bpd;\n    log_dir /var/log/shiny-server;\n    directory_index off;\n  }\n}\n' \
    > /etc/shiny-server/shiny-server.conf

# Health check so run_dashboard.sh can wait for readiness
HEALTHCHECK --interval=15s --timeout=5s --start-period=90s --retries=6 \
  CMD curl -sf http://localhost:3838/ || exit 1

EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
