FROM rocker/shiny:4.3.1

LABEL maintainer="Baltimore City PD Homicide Dashboard"
LABEL description="Interactive Shiny dashboard for homicide trend analysis"

# System dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgdal-dev \
    libproj-dev \
    libgeos-dev \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')); \
    install.packages(c( \
        'shiny', \
        'shinydashboard', \
        'rvest', \
        'dplyr', \
        'stringr', \
        'lubridate', \
        'ggplot2', \
        'plotly', \
        'leaflet', \
        'DT', \
        'httr' \
    ), Ncpus = parallel::detectCores())"

# Copy the Shiny app
COPY app.R /srv/shiny-server/homicide/app.R

# Shiny server config: disable hosting of sample apps, set log level
RUN echo 'run_as shiny;\n\
server {\n\
  listen 3838;\n\
  location /homicide {\n\
    app_dir /srv/shiny-server/homicide;\n\
    log_dir /var/log/shiny-server;\n\
    directory_index off;\n\
  }\n\
  location / {\n\
    app_dir /srv/shiny-server/homicide;\n\
    log_dir /var/log/shiny-server;\n\
    directory_index off;\n\
  }\n\
}' > /etc/shiny-server/shiny-server.conf

# Make log dir writable
RUN mkdir -p /var/log/shiny-server && \
    chown -R shiny:shiny /var/log/shiny-server && \
    chown -R shiny:shiny /srv/shiny-server && \
    mkdir -p /tmp && chmod 777 /tmp

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
