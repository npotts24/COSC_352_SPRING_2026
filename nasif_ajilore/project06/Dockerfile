FROM rocker/shiny:latest

# System libs needed by spatial packages (leaflet etc.) and rvest
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl-dev libcurl4-openssl-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Use Posit Package Manager pre-compiled binaries for Ubuntu 24.04
ENV REPOS="https://packagemanager.posit.co/cran/__linux__/noble/latest"

RUN R -e "install.packages('shinydashboard', repos='${REPOS}')"
RUN R -e "install.packages('rvest',          repos='${REPOS}')"
RUN R -e "install.packages('stringr',        repos='${REPOS}')"
RUN R -e "install.packages('ggplot2',        repos='${REPOS}')"
RUN R -e "install.packages('plotly',         repos='${REPOS}')"
RUN R -e "install.packages('DT',             repos='${REPOS}')"

# Create app directory
RUN rm -rf /srv/shiny-server/*
RUN mkdir -p /srv/shiny-server/app/data

# Copy app code and data
COPY app.R /srv/shiny-server/app/app.R
COPY data/homicides_cache.csv /srv/shiny-server/app/data/homicides_cache.csv

# Custom shiny-server config (app_dir instead of site_dir)
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
